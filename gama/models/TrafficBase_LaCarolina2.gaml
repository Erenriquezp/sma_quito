/**
 * TrafficBase_LaCarolina2.gaml
 * SMA — Escenario 0 (baseline sin peaje), zona de cobro por congestión, Quito.
 * UCE — Sistemas Colaborativos 2026.
 *
 * Modelo configurable: el mapa se elige por parámetro (nombre_mapa) y la zona de
 * cobro se construye a partir de los puntos de control que el usuario coloca por
 * doble clic. En E0 los puntos no cobran (modo_peaje_activo = false).
 * Salida: outputs/E0_metricas.csv (escenario "E0").
 */

model TrafficBase_LaCarolina

global {

	// ── Mapa intercambiable ───────────────────────────────────────────────────
	string nombre_mapa <- "mapaCarolina.shp" among: ["red_vial_la_carolina.shp", "mapaCarolina.shp", "mapaQuicentroSur.shp"];
	file road_shapefile <- file("../includes/" + nombre_mapa);
	geometry shape      <- envelope(road_shapefile);
	float step          <- 10 #s;

	// ── Puntos de control colocados por el usuario (doble clic) ────────────────
	list<point> puntos_control_usuario <- [];
	point punto_pendiente   <- nil;
	point ultimo_click      <- nil;
	int   ciclo_ultimo_click <- -999;

	reflex crear_punto_control when: punto_pendiente != nil {
		puntos_control_usuario << punto_pendiente;
		create PuntoControl with: [
			id_control::length(puntos_control_usuario),
			nombre_acceso::"C" + string(length(puntos_control_usuario)),
			location::punto_pendiente,
			tarifa_vigente::0.0,
			modo_peaje_activo::false   // E0: los puntos no cobran
		];

		// La zona de cobro (manta azul) es la envolvente convexa de los puntos
		// colocados. Requiere >= 3 puntos; los clics ya están en coordenadas del
		// modelo, así que el polígono queda alineado con el mapa activo.
		if (length(puntos_control_usuario) >= 3) {
			zona_peaje <- convex_hull(polygon(puntos_control_usuario));
			lbl_zona   <- zona_peaje.location;
		}
		punto_pendiente <- nil;
	}

	// ── Inyección de tráfico en hora pico (oleadas de ingreso a la zona) ───────
	reflex inyectar_trafico_hora_pico when: es_hora_pico and (dia_semana >= 1 and dia_semana <= 5) {
		if (cycle mod 3 = 0) {
			list<road> pool_vias <- empty(roads_conectadas) ? list(road) : roads_conectadas;
			create ConductorBDI number: 2 {
				tipo_vehiculo   <- one_of(["AUTO", "SUV", "MOTO", "CARGA"]);
				road rd <- one_of(pool_vias);
				location <- any_location_in(rd);
				destino  <- any_location_in(one_of(pool_vias));
				decision_tomada <- false;
			}
			if (cycle mod 12 = 0) {
				create ConductorBDI number: 1 {
					tipo_vehiculo   <- "BUS";
					road rd <- one_of(pool_vias);
					location <- any_location_in(rd);
					destino  <- any_location_in(one_of(pool_vias));
					decision_tomada <- false;
				}
			}
		}
	}

	// ── Reloj (06:00–22:00) y franjas pico (07–10 h, 17–20 h) ──────────────────
	int hora_inicio_sim      <- 360;
	int hora_fin_sim         <- 1320;
	int minuto_actual        <- 360;
	int HORA_PICO_MAT_INICIO <- 420;
	int HORA_PICO_MAT_FIN    <- 600;
	int HORA_PICO_VES_INICIO <- 1020;
	int HORA_PICO_VES_FIN    <- 1200;
	bool es_hora_pico        <- false;

	// ── Flota por tipo de vehículo (distribución parque automotor DMQ) ─────────
	int NB_MOTOS  <- 45;    // ~15 %
	int NB_AUTOS  <- 165;   // ~55 %
	int NB_SUVS   <- 45;    // ~15 %
	int NB_BUSES  <- 30;    // ~10 % — exonerados (SMA.md §7.2)
	int NB_CARGAS <- 15;    // ~5 %

	// ── Perfil socioeconómico (NSE) ────────────────────────────────────────────
	float PCT_NSE_ALTO  <- 0.15;
	float PCT_NSE_MEDIO <- 0.45;
	float PCT_NSE_BAJO  <- 0.40;
	float WTP_NSE_ALTO  <- 3.00;
	float WTP_NSE_MEDIO <- 2.25;
	float WTP_NSE_BAJO  <- 0.50;

	// ── Tercera placa ──────────────────────────────────────────────────────────
	float PCT_RESTRICCION_PLACA <- 0.20;
	int   RESTRICCION_INICIO    <- 360;
	int   RESTRICCION_FIN       <- 1200;
	int   dia_semana            <- 1;

	float COSTO_METRO   <- 0.45;
	float VEL_LIBRE_KMH <- 50.0;   // flujo libre; la velocidad media emergente = VEL_LIBRE × coef. de congestión

	// Icono de vehículo (se carga una sola vez). Disponibles: voit_blue / voit_red / voit.png (negro).
	image_file ICON_VEHICULO <- image_file("../includes/voit_blue.png");
	// Tamaño de los vehículos en unidades de mundo (slider "Vista"), ajustable en caliente.
	float ESCALA_VEHICULO <- 10.0;

	string CRS_DATOS <- "EPSG:32717";   // UTM 17S — usado por las estaciones Metro

	// ── Zona de cobro (envolvente de los puntos C#; vacía hasta tener >= 3) ────
	geometry zona_peaje;
	point    lbl_zona;

	// ── Red vial ───────────────────────────────────────────────────────────────
	graph road_network;
	map<road, float> road_weights;
	list<road> roads_conectadas <- [];

	// ── Métricas ─────────────────────────────────────────────────────────────
	float velocidad_media  <- 0.0;
	int   modal_shift_acum <- 0;

	int    INTERVALO_LOG <- 90;
	string OUTPUT_PATH   <- "../outputs/";
	bool   csv_header_escrito <- false;

	init {
		write "=== ESCENARIO E0 — BASELINE SIN PEAJE | Mapa: " + nombre_mapa + " ===";

		create road from: road_shapefile;
		road_weights <- road as_map (each :: each.shape.perimeter);
		road_network <- as_edge_graph(road);

		graph main_graph <- main_connected_component(road_network);
		roads_conectadas <- road where (main_graph contains_edge each.shape);
		if empty(roads_conectadas) {
			roads_conectadas <- road where (main_graph contains_node (first(each.shape.points)));
		}
		if empty(roads_conectadas) { roads_conectadas <- list(road); }
		road_network <- main_graph;
		road_weights <- roads_conectadas as_map (each :: each.shape.perimeter);

		// La zona de cobro se construye con los clics del usuario (ver crear_punto_control).
		zona_peaje <- nil;
		lbl_zona   <- nil;
		if (nombre_mapa contains "Sur") { step <- 2 #s; }

		// Estaciones Metro solo en La Carolina (Iñaquito y La Carolina).
		if (not (nombre_mapa contains "Sur")) {
			create EstacionMetro with: [nombre::"Iñaquito",    location::(to_GAMA_CRS({780119.0, 9980458.0}, CRS_DATOS)).location];
			create EstacionMetro with: [nombre::"La Carolina", location::(to_GAMA_CRS({779831.0, 9978891.0}, CRS_DATOS)).location];
		}

		list<road> road_pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
		create ConductorBDI number: NB_MOTOS  { tipo_vehiculo <- "MOTO";  road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }
		create ConductorBDI number: NB_AUTOS  { tipo_vehiculo <- "AUTO";  road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }
		create ConductorBDI number: NB_SUVS   { tipo_vehiculo <- "SUV";   road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }
		create ConductorBDI number: NB_BUSES  { tipo_vehiculo <- "BUS";   road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }
		create ConductorBDI number: NB_CARGAS { tipo_vehiculo <- "CARGA"; road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }

		string archivo_csv <- OUTPUT_PATH + "E0_metricas.csv";
		save ["escenario","minuto","hora","es_hora_pico",
		      "nb_conductores","velocidad_media_kmh",
		      "pct_ruta_directa","pct_reroutean","pct_metro","modal_shift_acum",
		      "nb_restringidos_placa",
		      "directo_nse_alto","directo_nse_medio","directo_nse_bajo",
		      "metro_nse_alto","metro_nse_medio","metro_nse_bajo",
		      "rerouta_nse_alto","rerouta_nse_medio","rerouta_nse_bajo"]
		to: archivo_csv format: "csv" rewrite: true;
		csv_header_escrito <- true;
	}

	reflex avanzar_reloj {
		minuto_actual <- hora_inicio_sim + int(cycle * step / 60.0);
		es_hora_pico  <-
			(minuto_actual >= HORA_PICO_MAT_INICIO and minuto_actual <= HORA_PICO_MAT_FIN) or
			(minuto_actual >= HORA_PICO_VES_INICIO and minuto_actual <= HORA_PICO_VES_FIN);
	}

	reflex update_road_speed {
		road_weights <- road as_map (each :: each.shape.perimeter / each.speed_coeff);
		road_network <- road_network with_weights road_weights;

		// Velocidad media = flujo libre × coef. de congestión medio de las vías
		// ocupadas DENTRO de la zona de cobro (fallback: toda la red ocupada).
		list<road> ocupadas <- (zona_peaje = nil)
		    ? []
		    : (roads_conectadas where (each.nb_people > 0.0 and each.shape intersects zona_peaje));
		if empty(ocupadas) { ocupadas <- roads_conectadas where (each.nb_people > 0.0); }
		float coef <- empty(ocupadas) ? 1.0 : mean(ocupadas collect each.speed_coeff);
		velocidad_media <- round(VEL_LIBRE_KMH * coef * 10.0) / 10.0;
	}

	reflex exportar_metricas when: (cycle mod INTERVALO_LOG = 0) and (cycle > 0) {
		string archivo <- OUTPUT_PATH + "E0_metricas.csv";

		// Cuota modal = snapshot de la intención actual de la flota.
		list<ConductorBDI> flota <- list(ConductorBDI);
		int n_directo <- flota count (each.intencion = "RUTA_DIRECTA");
		int n_reroute <- flota count (each.intencion = "REROUTEAR");
		int n_metro   <- flota count (each.intencion = "METRO");
		int total     <- max(1, n_directo + n_reroute + n_metro);
		float pd <- n_directo / float(total) * 100.0;
		float pr <- n_reroute / float(total) * 100.0;
		float pm <- n_metro   / float(total) * 100.0;

		int s_directo_alto  <- flota count (each.intencion="RUTA_DIRECTA" and each.nse="ALTO");
		int s_directo_medio <- flota count (each.intencion="RUTA_DIRECTA" and each.nse="MEDIO");
		int s_directo_bajo  <- flota count (each.intencion="RUTA_DIRECTA" and each.nse="BAJO");
		int s_metro_alto    <- flota count (each.intencion="METRO" and each.nse="ALTO");
		int s_metro_medio   <- flota count (each.intencion="METRO" and each.nse="MEDIO");
		int s_metro_bajo    <- flota count (each.intencion="METRO" and each.nse="BAJO");
		int s_rerouta_alto  <- flota count (each.intencion="REROUTEAR" and each.nse="ALTO");
		int s_rerouta_medio <- flota count (each.intencion="REROUTEAR" and each.nse="MEDIO");
		int s_rerouta_bajo  <- flota count (each.intencion="REROUTEAR" and each.nse="BAJO");
		int s_restringidos  <- flota count (each.restringido_placa and minuto_actual >= RESTRICCION_INICIO and minuto_actual <= RESTRICCION_FIN);

		modal_shift_acum <- empty(EstacionMetro) ? 0 : sum(EstacionMetro collect each.modal_shift_total);

		int    hh       <- int(minuto_actual / 60);
		int    mm       <- minuto_actual mod 60;
		string hora_str <- string(hh) + ":" + (mm < 10 ? "0" : "") + string(mm);

		save ["E0", minuto_actual, hora_str, es_hora_pico,
		      length(ConductorBDI), velocidad_media,
		      round(pd * 10) / 10.0, round(pr * 10) / 10.0, round(pm * 10) / 10.0,
		      modal_shift_acum, s_restringidos,
		      s_directo_alto, s_directo_medio, s_directo_bajo,
		      s_metro_alto,   s_metro_medio,   s_metro_bajo,
		      s_rerouta_alto, s_rerouta_medio, s_rerouta_bajo]
		to: archivo format: "csv" rewrite: false;
	}

	reflex fin_sim when: minuto_actual >= hora_fin_sim {
		write "SIMULACIÓN E0 COMPLETADA — vel. final: " + round(velocidad_media) + " km/h";
		do pause;
	}
}

species road {
	float capacity    <- 1 + shape.perimeter / 30;
	// Los agentes que se pasan al Metro no congestionan la vía (se excluyen).
	float nb_people   <- 0.0 update: sum((ConductorBDI at_distance 10) where (each.intencion != "METRO") collect each.factor_capacidad_via);
	float speed_coeff <- 1.0 update: exp(-nb_people / capacity) min: 0.1;
	aspect default {
		// Mapa de calor de congestión (paleta pastel): el flujo libre es un gris-azulado
		// claro y neutro que actúa de fondo; solo la congestión (ámbar → coral) resalta.
		rgb c <- (speed_coeff > 0.6) ? rgb(140, 155, 168)
		        : ((speed_coeff > 0.35) ? rgb(222, 188, 130) : rgb(220, 130, 120));
		// Grosor por ocupación: las vías con más tráfico se ven más gruesas.
		draw shape color: c width: min(6.0, 1.5 + nb_people * 0.4);
	}
}

species PuntoControl {
	int    id_control        <- 0;
	string nombre_acceso     <- "";
	float  tarifa_vigente    <- 0.0;
	bool   modo_peaje_activo <- false;

	aspect default {
		bool activo <- tarifa_vigente > 0.0;
		rgb  c      <- activo ? rgb(220, 40, 40) : rgb(110, 120, 130);
		draw box(36, 36, (activo ? 90 : 40)) at: location color: rgb(c, 0.92) border: #white;
		draw "C" + id_control at: location + {0, 0, (activo ? 100 : 50)} color: #white font: font("Arial", 13, #bold);
	}
}

species EstacionMetro {
	string nombre            <- "";
	int    pasajeros_espera  <- 0;
	int    modal_shift_total <- 0;
	int    capacidad_hora    <- 8000;
	bool   saturada          <- false update: (pasajeros_espera > capacidad_hora * 0.9);

	reflex salida_tren when: (cycle mod 30 = 0) {
		int abordan       <- min(pasajeros_espera, 300);
		pasajeros_espera  <- pasajeros_espera - abordan;
		modal_shift_total <- modal_shift_total + abordan;
	}

	aspect default {
		rgb c <- saturada ? rgb(220, 60, 60) : rgb(40, 120, 220);
		draw circle(78) at: location color: rgb(c, 0.16);
		draw circle(48) at: location color: c border: #white depth: 8;
		draw "M" at: location + {0, 0, 12} color: #white font: font("Arial", 24, #bold);
		draw nombre at: location + {0, -82, 6} color: #white font: font("Arial", 11, #bold);
	}
}

species ConductorBDI skills: [moving] {

	// Perfil socioeconómico
	string nse               <- "MEDIO";
	float  wtp               <- 1.50;
	float  w_tiempo          <- 0.35;
	float  w_costo           <- 0.35;
	float  w_comodidad       <- 0.30;
	bool   metro_accesible   <- false;
	bool   restringido_placa <- false;
	float  tarifa_percibida  <- 0.0;
	float  speed             <- (rnd(5.0) + 3.0) * 10.0;
	float  nivel_congestion  <- 0.0;
	float  umbral_congestion <- 0.55;

	// Tipo de vehículo
	string tipo_vehiculo        <- "AUTO";   // MOTO | AUTO | SUV | BUS | CARGA
	float  factor_capacidad_via <- 1.0;      // peso en road.nb_people
	float  tarifa_efectiva      <- 0.0;      // tarifa que realmente paga
	bool   exonerado_peaje      <- false;

	// Estado de movimiento
	point  destino           <- nil;
	string intencion         <- "RUTA_DIRECTA";
	bool   decision_tomada   <- false;
	int    t_sin_avanzar     <- 0;
	point  pos_anterior      <- nil;
	float  dist_ultimo_ciclo <- 0.0;

	init {
		float r <- rnd(1.0);
		if (r < PCT_NSE_ALTO) {
			nse <- "ALTO";  wtp <- WTP_NSE_ALTO;
			w_tiempo <- 0.35; w_costo <- 0.15; w_comodidad <- 0.50;
			speed <- speed + 30.0;
			umbral_congestion <- 0.40;
		} else if (r < PCT_NSE_ALTO + PCT_NSE_MEDIO) {
			nse <- "MEDIO"; wtp <- WTP_NSE_MEDIO;
			w_tiempo <- 0.35; w_costo <- 0.35; w_comodidad <- 0.30;
			umbral_congestion <- 0.55;
		} else {
			nse <- "BAJO";  wtp <- WTP_NSE_BAJO;
			w_tiempo <- 0.20; w_costo <- 0.65; w_comodidad <- 0.15;
			speed <- max(10.0, speed - 10.0);
			umbral_congestion <- 0.70;
		}
		restringido_placa <- (rnd(1.0) < PCT_RESTRICCION_PLACA) and (dia_semana >= 1 and dia_semana <= 5);
		metro_accesible   <- rnd(1.0) < 0.60;
		pos_anterior      <- location;

		// Propiedades físicas por tipo de vehículo
		if (tipo_vehiculo = "MOTO") {
			speed                <- speed + 40.0;
			factor_capacidad_via <- 0.3;
			exonerado_peaje      <- true;
			umbral_congestion    <- max(0.20, umbral_congestion - 0.15);
		} else if (tipo_vehiculo = "SUV") {
			speed                <- max(20.0, speed - 10.0);
			factor_capacidad_via <- 1.5;
			wtp                  <- wtp * 1.3;
		} else if (tipo_vehiculo = "BUS") {
			speed                <- max(15.0, speed - 35.0);
			factor_capacidad_via <- 3.0;
			exonerado_peaje      <- true;
			metro_accesible      <- false;
			restringido_placa    <- false;
			nse                  <- "BAJO";
		} else if (tipo_vehiculo = "CARGA") {
			speed                <- max(10.0, speed - 40.0);
			factor_capacidad_via <- 2.5;
			metro_accesible      <- false;
			restringido_placa    <- false;
			nse                  <- "BAJO";
		}

		if (nombre_mapa contains "Sur") { speed <- speed * 0.08; }
	}

	reflex percibir {
		ask PuntoControl at_distance 300 { myself.tarifa_percibida <- self.tarifa_vigente; }
		tarifa_efectiva <- exonerado_peaje ? 0.0 : tarifa_percibida;

		list<road> vias_cercanas <- road at_distance 200;
		nivel_congestion <- empty(vias_cercanas)
		    ? 0.0
		    : length(vias_cercanas where (each.speed_coeff <= 0.5)) / float(length(vias_cercanas));
	}

	reflex deliberar when: not decision_tomada and (
	                   nivel_congestion >= umbral_congestion
	                   or (restringido_placa and minuto_actual >= RESTRICCION_INICIO and minuto_actual <= RESTRICCION_FIN)
	               ) {
		do decidir();
	}

	action decidir {
		// El bus siempre toma ruta directa (transporte público de ruta fija).
		if (tipo_vehiculo = "BUS") {
			intencion       <- "RUTA_DIRECTA";
			decision_tomada <- true;
			return;
		}

		// Placa restringida: cambio modal al Metro si es accesible, si no rerouteo.
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO and minuto_actual <= RESTRICCION_FIN) {
			intencion <- (metro_accesible and not empty(EstacionMetro)) ? "METRO" : "REROUTEAR";
			if (intencion = "METRO") {
				ask (EstacionMetro closest_to self) { if not saturada { pasajeros_espera <- pasajeros_espera + 1; } }
			}
			decision_tomada <- true;
			return;
		}

		// Decisión por utilidad multicriterio.
		float ud <- u_directa();
		float ur <- u_reroutear();
		float um <- (not empty(EstacionMetro)) ? u_metro() : 0.0;

		if (ud >= ur and ud >= um) {
			intencion <- "RUTA_DIRECTA";
		} else if (um > ur and metro_accesible and not empty(EstacionMetro)) {
			intencion <- "METRO";
			ask (EstacionMetro closest_to self) { if not saturada { pasajeros_espera <- pasajeros_espera + 1; } }
		} else {
			intencion <- "REROUTEAR";
		}
		decision_tomada <- true;
	}

	float u_directa {
		if tarifa_efectiva > wtp { return -0.5; }
		float uc <- (tarifa_efectiva > 0) ? (1.0 / tarifa_efectiva) : 1.0;
		float congestion_penalty <- 1.0 - (nivel_congestion * 0.5);
		return w_tiempo * (1.0 / max(1.0, speed)) + w_costo * uc + w_comodidad * (0.90 * congestion_penalty);
	}

	float u_reroutear {
		float congestion_bonus <- nivel_congestion * 0.30;
		return w_tiempo * (1.0 / max(1.0, speed * 0.65)) + w_costo * 1.0 + w_comodidad * (0.60 + congestion_bonus);
	}

	float u_metro {
		if not metro_accesible { return 0.0; }
		float congestion_bonus <- nivel_congestion * 0.20;
		return w_tiempo * (1.0 / 12.0) + w_costo * (1.0 / COSTO_METRO) + w_comodidad * (0.70 + congestion_bonus);
	}

	reflex mover when: destino != nil {
		// Placa restringida e intención no-Metro: el vehículo queda inmovilizado.
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO and minuto_actual <= RESTRICCION_FIN and intencion != "METRO") {
			dist_ultimo_ciclo <- 0.0;
			if (cycle mod 300 = 0) {
				list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
				destino <- any_location_in(one_of(pool));
			}
			return;
		}
		do goto target: destino on: road_network move_weights: road_weights speed: speed;

		dist_ultimo_ciclo <- (pos_anterior != nil) ? (location distance_to pos_anterior) : 0.0;
		t_sin_avanzar <- (dist_ultimo_ciclo < 1.0) ? t_sin_avanzar + 1 : 0;
		pos_anterior  <- copy(location);

		if (location distance_to destino < 150 or t_sin_avanzar > 1200) {
			list<road> pool  <- empty(roads_conectadas) ? list(road) : roads_conectadas;
			destino          <- any_location_in(one_of(pool));
			decision_tomada  <- false;
			intencion        <- "RUTA_DIRECTA";
			tarifa_percibida <- 0.0;
			tarifa_efectiva  <- 0.0;
			t_sin_avanzar    <- 0;
		}
	}

	reflex nuevo_destino when: destino = nil {
		list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
		destino <- any_location_in(one_of(pool));
	}

	aspect default {
		rgb col <- #gray;
		if      (tipo_vehiculo = "MOTO")  { col <- #deepskyblue;  }
		else if (tipo_vehiculo = "AUTO")  { col <- #dodgerblue;   }
		else if (tipo_vehiculo = "SUV")   { col <- #mediumpurple; }
		else if (tipo_vehiculo = "BUS")   { col <- #limegreen;    }
		else if (tipo_vehiculo = "CARGA") { col <- #sienna;       }

		if (decision_tomada) {
			if      (intencion = "REROUTEAR") { col <- #orange; }
			else if (intencion = "METRO")     { col <- #gold;   }
		}
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO and minuto_actual <= RESTRICCION_FIN) { col <- #red; }

		float sz <- 8.0;
		if      (tipo_vehiculo = "MOTO")  { sz <- 5.0;  }
		else if (tipo_vehiculo = "SUV")   { sz <- 10.0; }
		else if (tipo_vehiculo = "BUS")   { sz <- 14.0; }
		else if (tipo_vehiculo = "CARGA") { sz <- 12.0; }
		float tam <- sz * ESCALA_VEHICULO;   // tamaño visible en unidades de mundo (ESCALA es un slider)

		// Halo de estado (color por tipo / decisión BDI) + icono de auto orientado al rumbo.
		// El icono da silueta y orientación; el halo conserva la lectura de tipo/decisión.
		bool dentro <- (zona_peaje != nil) and (location intersects zona_peaje);
		draw circle(tam * 0.55) at: location + {0, 0, 3} color: rgb(col, dentro ? 0.85 : 0.40) border: (dentro ? #white : #black);
		draw ICON_VEHICULO size: tam rotate: heading + 180 at: location + {0, 0, 6};
	}
}

experiment "Simulacion Base Heterogenea" type: gui autorun: false {

	parameter "Motos (~15 %)"              var: NB_MOTOS   min: 0 max: 150 step: 15 category: "Vehículos";
	parameter "Autos particulares (~55 %)" var: NB_AUTOS   min: 0 max: 300 step: 25 category: "Vehículos";
	parameter "SUV / 4x4 (~15 %)"          var: NB_SUVS    min: 0 max: 150 step: 15 category: "Vehículos";
	parameter "Buses / T. público (~10 %)" var: NB_BUSES   min: 0 max: 100 step: 10 category: "Vehículos";
	parameter "Vehículos de carga (~5 %)"  var: NB_CARGAS  min: 0 max: 50  step: 5  category: "Vehículos";
	parameter "Día semana (1=Lun,7=Dom)"   var: dia_semana min: 1 max: 7            category: "Sim";
	parameter "Seleccionar Entorno Vial:"  var: nombre_mapa                         category: "Mapa";
	parameter "Tamaño vehículos"           var: ESCALA_VEHICULO min: 2.0 max: 40.0 step: 2.0 category: "Vista";

	float minimum_cycle_duration <- 0.01;

	action marcar_punto_control {
		point p <- #user_location;
		if (ultimo_click != nil and cycle - ciclo_ultimo_click <= 10 and p distance_to ultimo_click < 40) {
			punto_pendiente <- p;
		}
		ultimo_click <- p;
		ciclo_ultimo_click <- cycle;
	}

	output synchronized: true {

		display "Mapa La Carolina — Base Heterogénea" type: 3d axes: false background: rgb(22, 24, 28) toolbar: false {

			event #mouse_down action: marcar_punto_control;

			overlay position: {18 #px, 18 #px} size: {250 #px, 412 #px}
			        background: rgb(15, 17, 22) border: rgb(70, 75, 85) rounded: true {
				int hh <- int(minuto_actual / 60);
				int mm <- minuto_actual mod 60;
				string reloj <- (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm;
				bool   fin_semana <- dia_semana >= 6;
				string dia_txt    <- (dia_semana <= 5) ? "Lun–Vie" : (dia_semana = 6 ? "Sábado · sin placa" : "Domingo · sin placa");

				draw "SMA · La Carolina" at: {14 #px, 13 #px} anchor: #top_left color: #orange font: font("Arial", 15, #bold);
				draw "Escenario E0 · Baseline (sin cobro)" at: {14 #px, 33 #px} anchor: #top_left color: rgb(140, 145, 155) font: font("Arial", 9, #plain);
				draw rectangle(222 #px, 1 #px) at: {125 #px, 52 #px} color: rgb(55, 60, 70);

				draw reloj at: {14 #px, 60 #px} anchor: #top_left color: #white font: font("Arial", 26, #bold);
				draw (es_hora_pico ? "● PICO" : "valle") at: {150 #px, 66 #px} anchor: #top_left color: (es_hora_pico ? #orange : rgb(110, 115, 125)) font: font("Arial", 12, #bold);
				draw dia_txt at: {150 #px, 86 #px} anchor: #top_left color: (fin_semana ? rgb(230, 180, 90) : rgb(140, 145, 155)) font: font("Arial", 9, #bold);

				draw "VELOCIDAD" at: {14 #px, 102 #px} anchor: #top_left color: rgb(130, 135, 145) font: font("Arial", 8, #bold);
				draw ("" + velocidad_media + " km/h") at: {14 #px, 115 #px} anchor: #top_left color: #white font: font("Arial", 13, #bold);
				draw "ZONA" at: {140 #px, 102 #px} anchor: #top_left color: rgb(130, 135, 145) font: font("Arial", 8, #bold);
				draw "LIBRE" at: {140 #px, 115 #px} anchor: #top_left color: #limegreen font: font("Arial", 13, #bold);
				draw rectangle(222 #px, 1 #px) at: {125 #px, 142 #px} color: rgb(55, 60, 70);

				float y <- 154 #px;
				draw "VEHÍCULOS" at: {14 #px, y} anchor: #top_left color: rgb(125, 130, 140) font: font("Arial", 9, #bold);
				y <- y + 18 #px;
				loop item over: [["Moto", #deepskyblue], ["Auto", #dodgerblue], ["SUV / 4x4", #mediumpurple], ["Bus", #limegreen], ["Carga", #sienna], ["Restringido (placa)", #red]] {
					draw circle(6 #px) at: {20 #px, y} color: rgb(rgb(item[1]), 0.95);
					draw string(item[0]) at: {34 #px, y} anchor: #left_center color: rgb(205, 208, 214) font: font("Arial", 10, #plain);
					y <- y + 20 #px;
				}
				y <- y + 6 #px;
				draw "DECISIÓN BDI" at: {14 #px, y} anchor: #top_left color: rgb(125, 130, 140) font: font("Arial", 9, #bold);
				y <- y + 18 #px;
				loop item over: [["Reroutan (vía periférica)", #orange], ["→ Metro (modal)", #gold]] {
					draw square(11 #px) at: {20 #px, y} color: rgb(rgb(item[1]), 0.9);
					draw string(item[0]) at: {34 #px, y} anchor: #left_center color: rgb(205, 208, 214) font: font("Arial", 10, #plain);
					y <- y + 20 #px;
				}

				// ── Línea de tiempo del día (06–22 h) con franjas pico sombreadas ──
				y <- y + 10 #px;
				draw rectangle(222 #px, 1 #px) at: {125 #px, y} color: rgb(55, 60, 70);
				y <- y + 14 #px;
				draw "PROGRESO DEL DÍA · 06–22 h" at: {14 #px, y} anchor: #top_left color: rgb(125, 130, 140) font: font("Arial", 9, #bold);
				y <- y + 16 #px;
				draw rectangle(222 #px, 6 #px) at: {125 #px, y} color: rgb(45, 50, 60);           // pista
				draw rectangle(41 #px, 6 #px)  at: {49 #px, y}  color: rgb(120, 90, 40);           // pico 07–10
				draw rectangle(41 #px, 6 #px)  at: {187 #px, y} color: rgb(120, 90, 40);           // pico 17–20
				draw circle(5 #px) at: {14 #px + ((minuto_actual - 360) / 960.0) * 222 #px, y}     // hora actual
				     color: (es_hora_pico ? #orange : #white) border: rgb(20, 22, 28);
			}

			light #ambient intensity: 130;
			species road refresh: true;

			graphics "Zona de cobro" {
				if (zona_peaje != nil) {
					draw zona_peaje color: rgb(rgb(60, 120, 205), 0.22) border: rgb(120, 190, 245) width: 4;
					// Sombra para legibilidad sobre la red vial, luego el texto.
					draw "ZONA DE COBRO" at: lbl_zona + {12, 12, 0} anchor: #left_center color: rgb(0, 0, 0, 0.7) font: font("Arial", 11, #bold);
					draw "ZONA DE COBRO" at: lbl_zona anchor: #left_center color: rgb(170, 200, 235) font: font("Arial", 11, #bold);
				}
			}

			species PuntoControl;
			species EstacionMetro;
			species ConductorBDI;
		}

		display "Decisiones BDI" {
			chart "Decisiones de la flota (instantánea)" type: pie background: rgb(25, 25, 25) color: #white series_label_position: onchart label_text_color: #black label_font: font("Arial", 12, #bold) legend_font: font("Arial", 11, #plain) {
				data "Ruta directa" value: ConductorBDI count (each.intencion = "RUTA_DIRECTA") color: #dodgerblue;
				data "Reroutan"     value: ConductorBDI count (each.intencion = "REROUTEAR")    color: #orange;
				data "→ Metro"      value: ConductorBDI count (each.intencion = "METRO")        color: #gold;
			}
		}
	}
}
