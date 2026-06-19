/**
 * TrafficBase_LaCarolina_V2_Heterogeneo.gaml
 * Modelo SMA — Zona de cobro por congestión, Parque La Carolina, Quito
 * UCE — Sistemas Colaborativos 2026
 *
 * Ajustes:
 * - Se eliminaron los puntos de control cableados en el código.
 * - Toda la red de puntos de control se define mediante doble clic en la interfaz.
 */

model TrafficBase_LaCarolina_V2_Heterogeneo

global {

	// 1. Parámetro de texto para elegir el mapa
	string nombre_mapa <- "red_vial_la_carolina.shp" among: ["red_vial_la_carolina.shp", "mapaCarolina.shp", "mapaQuicentroSur.shp"];

	// 2. Carga dinámica del mapa seleccionado
	file road_shapefile <- file("../includes/" + nombre_mapa);
	geometry shape      <- envelope(road_shapefile);
	float step          <- 10 #s;

	// ── INYECCIÓN INTERACTIVA DE PUNTOS DE CONTROL (Doble Clic) ─────────────
	list<point> puntos_control_usuario <- [];
	point punto_pendiente <- nil;
	point ultimo_click <- nil;
	int ciclo_ultimo_click <- -999;

	reflex crear_punto_control when: punto_pendiente != nil {
		puntos_control_usuario << punto_pendiente;

		create PuntoControl with: [
			id_control::length(puntos_control_usuario), // Arranca desde el ID 1 en adelante
			nombre_acceso::"PC_Usuario_" + string(length(puntos_control_usuario)),
			location::punto_pendiente,
			tarifa_vigente::0.0,
			modo_peaje_activo::false // En E0 se mantiene inactivo (sin cobro)
		];

		write "Punto de control (Baseline) agregado por el usuario en: X=" + string(punto_pendiente.x) + " Y=" + string(punto_pendiente.y);
		punto_pendiente <- nil;
	}

	// ── INYECCIÓN DINÁMICA DE TRÁFICO EN HORA PICO ───────────────────
	reflex inyectar_trafico_hora_pico when: es_hora_pico and (dia_semana >= 1 and dia_semana <= 5) {
		
		if (cycle mod 3 = 0) {
			list<road> pool_vias <- empty(roads_conectadas) ? list(road) : roads_conectadas;
			
			create ConductorBDI number: 2 {
				tipo_vehiculo <- one_of(["AUTO", "SUV", "MOTO", "CARGA"]);
				road rd <- one_of(pool_vias);
				location <- any_location_in(rd);
				destino  <- any_location_in(one_of(pool_vias));
				decision_tomada <- false; 
			}
			
			if (cycle mod 12 = 0) {
				create ConductorBDI number: 1 {
					tipo_vehiculo <- "BUS";
					road rd <- one_of(pool_vias);
					location <- any_location_in(rd);
					destino  <- any_location_in(one_of(pool_vias));
					decision_tomada <- false;
				}
			}
		}
	}

	// ── Reloj ────────────────────────────────────────────────────────────────
	int hora_inicio_sim      <- 360;   // 06:00 en minutos del día
	int hora_fin_sim         <- 1320;  // 22:00 en minutos del día
	int minuto_actual        <- 360;
	int HORA_PICO_MAT_INICIO <- 420;
	int HORA_PICO_MAT_FIN    <- 600;
	int HORA_PICO_VES_INICIO <- 1020;
	int HORA_PICO_VES_FIN    <- 1200;
	bool es_hora_pico        <- false;

	// ── Parámetros de la Flota ───────────────────────────────────────────────
	int NB_MOTOS  <- 45;    
	int NB_AUTOS  <- 165;   
	int NB_SUVS   <- 45;    
	int NB_BUSES  <- 30;    
	int NB_CARGAS <- 15;    
	
	float PCT_NSE_ALTO          <- 0.15;
	float PCT_NSE_MEDIO         <- 0.45;
	float PCT_NSE_BAJO          <- 0.40;
	float WTP_NSE_ALTO          <- 3.00;
	float WTP_NSE_MEDIO         <- 2.25;
	float WTP_NSE_BAJO          <- 0.50;
	int   dia_semana            <- 1;

	float PCT_RESTRICCION_PLACA <- 0.20;
	int   RESTRICCION_INICIO    <- 360;
	int   RESTRICCION_FIN       <- 1200;

	// ── Peaje (Inactivo en E0) ───────────────────────────────────────────────
	float TARIFA_VALLE <- 0.00;
	float TARIFA_PICO_AUTO <- 2.00;
	float COSTO_METRO <- 0.45;
	float VEL_LIBRE_KMH <- 50.0;

	string CRS_DATOS <- "EPSG:32717";
	geometry zona_peaje;
	point    lbl_zona;   

	// ── Red vial ─────────────────────────────────────────────────────────────
	graph road_network;
	map<road, float> road_weights;
	list<road> roads_conectadas <- [];

	// ── Métricas globales de decisiones ─────────────────────────────────────
	int   count_ruta_directa <- 0;
	int   count_reroutean    <- 0;
	int   count_metro        <- 0;
	int   chart_ruta_directa <- 0;
	int   chart_reroutean    <- 0;
	int   chart_metro        <- 0;
	int   count_restringidos <- 0;
	int   chart_restringidos <- 0;

	float velocidad_media    <- 0.0;
	int   modal_shift_acum   <- 0;

	// ── Métricas desagregadas por NSE ────────────────────────────────────────
	int   count_directo_alto  <- 0;
	int   count_directo_medio <- 0;
	int   count_directo_bajo  <- 0;
	int   count_metro_alto    <- 0;
	int   count_metro_medio   <- 0;
	int   count_metro_bajo    <- 0;
	int   count_rerouta_alto  <- 0;
	int   count_rerouta_medio <- 0;
	int   count_rerouta_bajo  <- 0;

	float recaudacion_acum   <- 0.0;
	int   INTERVALO_LOG      <- 90;   
	string OUTPUT_PATH       <- "../outputs/";
	bool   csv_header_escrito <- false;

	init {
		write "=================================================";
		write "  ESCENARIO 0 MODIFICADO — BASELINE HETEROGÉNEO";
		write "  SIN PEAJE FIJO - PUNTOS DE CONTROL DINÁMICOS";
		write "  Mapa activo: " + nombre_mapa;
		write "  SMA Movilidad Quito — UCE 2026";
		write "=================================================";

		create road from: road_shapefile;

		road_weights <- road as_map (each :: each.shape.perimeter);
		road_network <- as_edge_graph(road);

		graph main_graph   <- main_connected_component(road_network);
		roads_conectadas   <- road where (main_graph contains_edge each.shape);
		
		if empty(roads_conectadas) {
			roads_conectadas <- road where (main_graph contains_node (first(each.shape.points)));
		}
		if empty(roads_conectadas) { roads_conectadas <- list(road); }

		road_network <- main_graph;
		road_weights <- roads_conectadas as_map (each :: each.shape.perimeter);

		// Calibración de BBOX según el mapa seleccionado
		if (nombre_mapa contains "Sur") {
			zona_peaje <- to_GAMA_CRS(polygon([{774500.0, 9965000.0}, {776000.0, 9965000.0},
			                                   {776000.0, 9966500.0}, {774500.0, 9966500.0}]), CRS_DATOS);
			lbl_zona   <- (to_GAMA_CRS({774550.0, 9964950.0}, CRS_DATOS)).location;
			step       <- 2 #s; 
		} else {
			zona_peaje <- to_GAMA_CRS(polygon([{779652.0, 9979104.0}, {780720.0, 9979104.0},
			                                   {780720.0, 9980535.0}, {779652.0, 9980535.0}]), CRS_DATOS);
			lbl_zona   <- (to_GAMA_CRS({779680.0, 9979060.0}, CRS_DATOS)).location;
		}

		// Se mantienen únicamente las estaciones de Metro si estamos en La Carolina
		if (not (nombre_mapa contains "Sur")) {
			create EstacionMetro with: [nombre::"Iñaquito", location::(to_GAMA_CRS({780119.0, 9980458.0}, CRS_DATOS)).location];
			create EstacionMetro with: [nombre::"La Carolina", location::(to_GAMA_CRS({779831.0, 9978891.0}, CRS_DATOS)).location];
		}

		// ── Creación de la Flota Vehicular ────────────────────────────────────
		list<road> road_pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
		
		create ConductorBDI number: NB_MOTOS  { tipo_vehiculo <- "MOTO";  road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }
		create ConductorBDI number: NB_AUTOS  { tipo_vehiculo <- "AUTO";  road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }
		create ConductorBDI number: NB_SUVS   { tipo_vehiculo <- "SUV";   road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }
		create ConductorBDI number: NB_BUSES  { tipo_vehiculo <- "BUS";   road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }
		create ConductorBDI number: NB_CARGAS { tipo_vehiculo <- "CARGA"; road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool)); }

		chart_ruta_directa <- 0;

		string archivo_csv <- OUTPUT_PATH + "E0_heterogeneo_metricas.csv";
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

		list<road> ocupadas <- roads_conectadas where (each.nb_people > 0.0 and each.shape intersects zona_peaje);
		if empty(ocupadas) { ocupadas <- roads_conectadas where (each.nb_people > 0.0); }
		float coef <- empty(ocupadas) ? 1.0 : mean(ocupadas collect each.speed_coeff);
		velocidad_media <- round(VEL_LIBRE_KMH * coef * 10.0) / 10.0;
	}

	reflex exportar_metricas when: (cycle mod INTERVALO_LOG = 0) and (cycle > 0) {
		string archivo <- OUTPUT_PATH + "E0_heterogeneo_metricas.csv";

		list<ConductorBDI> flota <- list(ConductorBDI);
		int n_directo <- flota count (each.intencion = "RUTA_DIRECTA");
		int n_reroute <- flota count (each.intencion = "REROUTEAR");
		int n_metro   <- flota count (each.intencion = "METRO");
		int total     <- max(1, n_directo + n_reroute + n_metro);
		float pd  <- n_directo / float(total) * 100.0;
		float pr  <- n_reroute / float(total) * 100.0;
		float pm  <- n_metro   / float(total) * 100.0;

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

		int    hh      <- int(minuto_actual / 60);
		int    mm      <- minuto_actual mod 60;
		string hora_str <- string(hh) + ":" + (mm < 10 ? "0" : "") + string(mm);

		save ["E0_HET", minuto_actual, hora_str, es_hora_pico,
		      length(ConductorBDI), velocidad_media,
		      round(pd * 10) / 10.0, round(pr * 10) / 10.0, round(pm * 10) / 10.0,
		      modal_shift_acum, s_restringidos,
		      s_directo_alto,  s_directo_medio,  s_directo_bajo,
		      s_metro_alto,    s_metro_medio,    s_metro_bajo,
		      s_rerouta_alto,  s_rerouta_medio,  s_rerouta_bajo]
		to: archivo format: "csv" rewrite: false;
	}

	reflex fin_sim when: minuto_actual >= hora_fin_sim {
		write "SIMULACIÓN COMPLETADA HETEROGÉNEA — vel. final: " + round(velocidad_media) + " km/h";
		do pause;
	}
}

species road {
	float capacity    <- 1 + shape.perimeter / 30;
	float nb_people   <- 0.0 update: sum((ConductorBDI at_distance 10) where (each.intencion != "METRO") collect each.factor_capacidad_via);
	float speed_coeff <- 1.0 update: exp(-nb_people / capacity) min: 0.1;
	aspect default { draw shape  color: #white width: 2; }
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

	string tipo_vehiculo        <- "AUTO"; 
	float  factor_capacidad_via <- 1.0;
	float  tarifa_efectiva      <- 0.0;
	bool   exonerado_peaje      <- false;

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

		if (tipo_vehiculo = "MOTO") {
			speed                <- speed + 40.0;   
			factor_capacidad_via <- 0.3;          
			exonerado_peaje      <- true;            
			umbral_congestion    <- max(0.20, umbral_congestion - 0.15); 
		} else if (tipo_vehiculo = "AUTO") {
			factor_capacidad_via <- 1.0;          
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

		if (nombre_mapa contains "Sur") {
			speed <- speed * 0.08; 
		}
	}

	reflex percibir {
		ask PuntoControl at_distance 300 {
			myself.tarifa_percibida <- self.tarifa_vigente;
		}
		tarifa_efectiva <- exonerado_peaje ? 0.0 : tarifa_percibida; 

		list<road> vias_cercanas <- road at_distance 200;
		if not empty(vias_cercanas) {
			int saturadas      <- length(vias_cercanas where (each.speed_coeff <= 0.5));
			nivel_congestion   <- saturadas / float(length(vias_cercanas));
		} else {
			nivel_congestion   <- 0.0;
		}
	}

	reflex deliberar when: not decision_tomada and (
	                   nivel_congestion >= umbral_congestion
	                   or (restringido_placa and minuto_actual >= RESTRICCION_INICIO and minuto_actual <= RESTRICCION_FIN)
	               ) {
		do decidir();
	}

	action decidir {
		if (tipo_vehiculo = "BUS") {
			intencion          <- "RUTA_DIRECTA";
			count_ruta_directa <- count_ruta_directa + 1;
			chart_ruta_directa <- chart_ruta_directa + 1;
			count_directo_bajo  <- count_directo_bajo + 1;
			decision_tomada    <- true;
			return;
		}

		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO and minuto_actual <= RESTRICCION_FIN) {
			count_restringidos <- count_restringidos + 1;
			chart_restringidos <- chart_restringidos + 1;
			intencion <- (metro_accesible and not empty(EstacionMetro)) ? "METRO" : "REROUTEAR";
			
			if intencion = "METRO" {
				ask (EstacionMetro closest_to self) {
					if not saturada { pasajeros_espera <- pasajeros_espera + 1; }
				}
				if      (nse = "ALTO")  { count_metro_alto  <- count_metro_alto  + 1; }
				else if (nse = "MEDIO") { count_metro_medio <- count_metro_medio + 1; }
				else                    { count_metro_bajo  <- count_metro_bajo  + 1; }
			} else {
				if      (nse = "ALTO")  { count_rerouta_alto  <- count_rerouta_alto  + 1; }
				else if (nse = "MEDIO") { count_rerouta_medio <- count_rerouta_medio + 1; }
				else                    { count_rerouta_bajo  <- count_rerouta_bajo  + 1; }
			}
			decision_tomada <- true;
			return;
		}

		float ud <- u_directa();
		float ur <- u_reroutear();
		float um <- (not empty(EstacionMetro)) ? u_metro() : 0.0;

		if (ud >= ur and ud >= um) {
			intencion          <- "RUTA_DIRECTA";
			count_ruta_directa <- count_ruta_directa + 1;
			chart_ruta_directa <- chart_ruta_directa + 1;
			if      (nse = "ALTO")  { count_directo_alto  <- count_directo_alto  + 1; }
			else if (nse = "MEDIO") { count_directo_medio <- count_directo_medio + 1; }
			else                    { count_directo_bajo  <- count_directo_bajo  + 1; }
		} else if (um > ur and metro_accesible and not empty(EstacionMetro)) {
			intencion   <- "METRO";
			count_metro <- count_metro + 1;
			chart_metro <- chart_metro + 1;
			ask (EstacionMetro closest_to self) {
				if not saturada { pasajeros_espera <- pasajeros_espera + 1; }
			}
			if      (nse = "ALTO")  { count_metro_alto  <- count_metro_alto  + 1; }
			else if (nse = "MEDIO") { count_metro_medio <- count_metro_medio + 1; }
			else                    { count_metro_bajo  <- count_metro_bajo  + 1; }
		} else {
			intencion       <- "REROUTEAR";
			count_reroutean <- count_reroutean + 1;
			chart_reroutean <- chart_reroutean + 1;
			if      (nse = "ALTO")  { count_rerouta_alto  <- count_rerouta_alto  + 1; }
			else if (nse = "MEDIO") { count_rerouta_medio <- count_rerouta_medio + 1; }
			else                    { count_rerouta_bajo  <- count_rerouta_bajo  + 1; }
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
		pos_anterior <- copy(location);

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
		if      (tipo_vehiculo = "MOTO")  { col <- #deepskyblue; }
		else if (tipo_vehiculo = "AUTO")  { col <- #dodgerblue;  }
		else if (tipo_vehiculo = "SUV")   { col <- #mediumpurple;}
		else if (tipo_vehiculo = "BUS")   { col <- #limegreen;   }
		else if (tipo_vehiculo = "CARGA") { col <- #sienna;      }

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

		bool dentro <- location intersects zona_peaje;
		if (dentro) {
			draw circle(sz) at: location + {0, 0, 5} color: col border: #white;
		} else {
			draw circle(sz) at: location + {0, 0, 5} color: rgb(col, 0.45) border: #black;
		}
	}
}

// ── Experimento E0 ─────────────────────────────────────────────────────────────
experiment "Simulacion Base Heterogenea" type: gui autorun: false {

	parameter "Motos (~15 %)"              var: NB_MOTOS   min: 0  max: 150 step: 15  category: "Vehículos";
	parameter "Autos particulares (~55 %)" var: NB_AUTOS   min: 0  max: 300 step: 25  category: "Vehículos";
	parameter "SUV / 4x4 (~15 %)"         var: NB_SUVS    min: 0  max: 150 step: 15  category: "Vehículos";
	parameter "Buses / T. público (~10 %)" var: NB_BUSES   min: 0  max: 100 step: 10  category: "Vehículos";
	parameter "Vehículos de carga (~5 %)"  var: NB_CARGAS  min: 0  max: 50  step: 5   category: "Vehículos";
	
	parameter "Día semana (1=Lun,7=Dom)"   var: dia_semana min: 1  max: 7             category: "Sim";
	parameter "Tarifa AUTO pico USD [EB]" var: TARIFA_PICO_AUTO min: 0.5 max: 3.0 step: 0.25 category: "[EB nominal]";
	parameter "Seleccionar Entorno Vial:"  var: nombre_mapa category: "Mapa";

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

			overlay position: {18 #px, 18 #px} size: {250 #px, 350 #px}
			        background: rgb(15, 17, 22) border: rgb(70, 75, 85) rounded: true {
				int hh <- int(minuto_actual / 60);
				int mm <- minuto_actual mod 60;
				string reloj <- (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm;

				draw "SMA · La Carolina" at: {14 #px, 13 #px} anchor: #top_left color: #orange font: font("Arial", 15, #bold);
				draw "Escenario E0 · Baseline (sin cobro)" at: {14 #px, 33 #px} anchor: #top_left color: rgb(140, 145, 155) font: font("Arial", 9, #plain);
				draw rectangle(222 #px, 1 #px) at: {125 #px, 52 #px} color: rgb(55, 60, 70);

				draw reloj at: {14 #px, 60 #px} anchor: #top_left color: #white font: font("Arial", 26, #bold);
				draw (es_hora_pico ? "● PICO" : "valle") at: {150 #px, 72 #px} anchor: #top_left color: (es_hora_pico ? #orange : rgb(110, 115, 125)) font: font("Arial", 12, #bold);

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
			}

			light #ambient intensity: 130;
			species road refresh: false;

			graphics "Zona La Carolina" {
				draw zona_peaje color: rgb(rgb(46, 109, 164), 0.10) border: rgb(120, 170, 220);
				draw (nombre_mapa contains "Sur" ? "ZONA QUICENTRO SUR" : "ZONA LA CAROLINA") at: lbl_zona anchor: #left_center color: rgb(140, 175, 215) font: font("Arial", 11, #bold);
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