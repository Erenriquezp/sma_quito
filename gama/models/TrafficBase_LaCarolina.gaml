/**
 * TrafficBase_LaCarolina_V2_Heterogeneo.gaml
 * Modelo SMA — Zona de cobro por congestión, Parque La Carolina, Quito
 * UCE — Sistemas Colaborativos 2026
 *
 */

model TrafficBase_LaCarolina_V2_Heterogeneo

global {

	file road_shapefile <- file("../includes/red_vial_la_carolina.shp");
	geometry shape      <- envelope(road_shapefile);
	float step          <- 10 #s;

	// ── Reloj ────────────────────────────────────────────────────────────────
	int hora_inicio_sim      <- 360;   // 06:00 en minutos del día
	int hora_fin_sim         <- 1320;  // 22:00 en minutos del día
	int minuto_actual        <- 360;
	int HORA_PICO_MAT_INICIO <- 420;
	int HORA_PICO_MAT_FIN    <- 600;
	int HORA_PICO_VES_INICIO <- 1020;
	int HORA_PICO_VES_FIN    <- 1200;
	bool es_hora_pico        <- false;

	// ── Parámetros de la Flota (Total Ajustado a Escala Equivalente) ─────────
	int NB_MOTOS  <- 45;    // ~15 % de la flota
	int NB_AUTOS  <- 165;   // ~55 %
	int NB_SUVS   <- 45;    // ~15 %
	int NB_BUSES  <- 30;    // ~10 % — Transporte Público Exonerado
	int NB_CARGAS <- 15;    // ~5 %
	
	float PCT_NSE_ALTO          <- 0.15;
	float PCT_NSE_MEDIO         <- 0.45;
	float PCT_NSE_BAJO          <- 0.40;
	float WTP_NSE_ALTO          <- 3.00;
	float WTP_NSE_MEDIO         <- 2.25;
	float WTP_NSE_BAJO          <- 0.50;
	int   dia_semana            <- 1;

	// §3.1 fix: pico y placa REINTRODUCIDO en E0 para igualar condiciones con EB.
	// SMA.md §8 define el baseline como "estado actual, con pico y placa activo, sin
	// cobro". Sin esta restricción, la comparación E0 vs EB no aislaba el efecto del
	// peaje (EB retiraba ~20 % de la flota por placa además de cobrar). Misma lógica
	// que EB_PeajeHorario.gaml: ~20 % de la flota, días hábiles, 06:00–20:00.
	float PCT_RESTRICCION_PLACA <- 0.20;
	int   RESTRICCION_INICIO    <- 360;
	int   RESTRICCION_FIN       <- 1200;

	// ── Peaje (Inactivo en E0) ───────────────────────────────────────────────
	float TARIFA_VALLE <- 0.00;
	
	float TARIFA_PICO_AUTO <- 2.00;
	// ── Costo referencia Metro (para función de utilidad) ────────────────────
	float COSTO_METRO <- 0.45;

	// ── Velocidad de flujo libre de referencia (km/h) ────────────────────────
	// La velocidad media emergente se estima como VEL_LIBRE_KMH × coeficiente de
	// congestión medio de las vías ocupadas DENTRO de la zona de cobro.
	float VEL_LIBRE_KMH <- 50.0;

	// ── CRS de los datos UTM ──────────────────────────────────────────────────
	// Las coordenadas reales (puntos de control, estaciones, zona) están en UTM
	// 17S (EPSG:32717). GAMA NORMALIZA el shapefile al cargarlo (lo desplaza a un
	// origen local), así que NO se puede usar el UTM crudo: hay que convertirlo con
	// to_GAMA_CRS(..., CRS_DATOS), que aplica el mismo desplazamiento que GAMA usó
	// en la red. Por eso zona_peaje y las posiciones se asignan en init (tras cargar
	// el shapefile, cuando el CRS ya está disponible).
	string CRS_DATOS <- "EPSG:32717";

	// ── Polígono de la zona de cobro (BBOX de los 5 puntos de control C1–C5) ──
	// La velocidad media se mide DENTRO de esta zona (la "velocidad en el polígono"
	// que compara el paper), para capturar el efecto del peaje sobre el tráfico de
	// paso y no diluirlo con la red periférica. Se asigna en init (UTM → CRS GAMA).
	geometry zona_peaje;
	point    lbl_zona;   // posición de la etiqueta de la zona (mundo, ya convertida)

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

	// ── Velocidad media emergente ─────────────────────────────────────────────
	float velocidad_media    <- 0.0;

	// ── Métricas de modal shift ───────────────────────────────────────────────
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
		write "  SIN PEAJE NI RESTRICCIÓN DE PLACA";
		write "  SMA Movilidad Quito — UCE 2026";
		write "=================================================";

    	create road from: road_shapefile;

		road_weights <- road as_map (each :: each.shape.perimeter);
		road_network <- as_edge_graph(road);

		graph main_graph   <- main_connected_component(road_network);
		roads_conectadas   <- road where (main_graph contains_edge each.shape);
		
		if empty(roads_conectadas) {
			roads_conectadas <- road where (
				main_graph contains_node (first(each.shape.points))
			);
		}
		if empty(roads_conectadas) { roads_conectadas <- list(road); }

		road_network <- main_graph;
		road_weights <- roads_conectadas as_map (each :: each.shape.perimeter);

		write "  Red vial: " + length(road) + " segmentos";
		write "  Componente principal: " + length(roads_conectadas) + " segmentos";

		// ── Zona de cobro y etiqueta (UTM 17S → CRS interno de GAMA) ──────────
		zona_peaje <- to_GAMA_CRS(polygon([{779652.0, 9979104.0}, {780720.0, 9979104.0},
		                                   {780720.0, 9980535.0}, {779652.0, 9980535.0}]),
		                          CRS_DATOS);
		lbl_zona   <- (to_GAMA_CRS({779680.0, 9979060.0}, CRS_DATOS)).location;

		// Puntos de Control (Estáticos en E0 - Sin Cobro). Coordenadas UTM reales
		// convertidas con to_GAMA_CRS para que calcen con la red normalizada.
		create PuntoControl with: [id_control::1, nombre_acceso::"C1-NacUnidas/Amazonas", location::(to_GAMA_CRS({779872.0, 9980535.0}, CRS_DATOS)).location, tarifa_vigente::0.0, modo_peaje_activo::false];
		create PuntoControl with: [id_control::2, nombre_acceso::"C2-NacUnidas/Shyris", location::(to_GAMA_CRS({780409.0, 9980309.0}, CRS_DATOS)).location, tarifa_vigente::0.0, modo_peaje_activo::false];
		create PuntoControl with: [id_control::3, nombre_acceso::"C3-Shyris/Republica", location::(to_GAMA_CRS({780196.0, 9979104.0}, CRS_DATOS)).location, tarifa_vigente::0.0, modo_peaje_activo::false];
		create PuntoControl with: [id_control::4, nombre_acceso::"C4-Amazonas/Republica", location::(to_GAMA_CRS({779652.0, 9979228.0}, CRS_DATOS)).location, tarifa_vigente::0.0, modo_peaje_activo::false];
		create PuntoControl with: [id_control::5, nombre_acceso::"C5-6Dic/NacUnidas", location::(to_GAMA_CRS({780720.0, 9980369.0}, CRS_DATOS)).location, tarifa_vigente::0.0, modo_peaje_activo::false];

		create EstacionMetro with: [nombre::"Iñaquito", location::(to_GAMA_CRS({780119.0, 9980458.0}, CRS_DATOS)).location];
		create EstacionMetro with: [nombre::"La Carolina", location::(to_GAMA_CRS({779831.0, 9978891.0}, CRS_DATOS)).location];

		// ── Creación Estructurada de la Flota Vehicular Heterogénea ─────────
		list<road> road_pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
		
		create ConductorBDI number: NB_MOTOS {
			tipo_vehiculo <- "MOTO";
			road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool));
		}
		create ConductorBDI number: NB_AUTOS {
			tipo_vehiculo <- "AUTO";
			road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool));
		}
		create ConductorBDI number: NB_SUVS {
			tipo_vehiculo <- "SUV";
			road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool));
		}
		create ConductorBDI number: NB_BUSES {
			tipo_vehiculo <- "BUS";
			road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool));
		}
		create ConductorBDI number: NB_CARGAS {
			tipo_vehiculo <- "CARGA";
			road rd <- one_of(road_pool); location <- any_location_in(rd); destino <- any_location_in(one_of(road_pool));
		}

		// §3.2 fix: arranca en 0 (antes inflaba el pastel con el tamaño de la flota).
		chart_ruta_directa <- 0;

		// CSV con columna nb_restringidos_placa (§3.1: E0 ahora reporta la placa igual que EB)
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

		write "  Total Conductores Heterogéneos: " + length(ConductorBDI);
		write "  Motos: "  + NB_MOTOS  + " | Autos: " + NB_AUTOS + " | SUV: " + NB_SUVS + " | Buses: " + NB_BUSES + " | Carga: " + NB_CARGAS;
		write "  NSE ALTO: "  + length(ConductorBDI where (each.nse = "ALTO"));
		write "  NSE MEDIO: " + length(ConductorBDI where (each.nse = "MEDIO"));
		write "  NSE BAJO: "  + length(ConductorBDI where (each.nse = "BAJO"));
		write "=================================================";
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

		// BUG-1 fix (v2): velocidad media = velocidad de flujo libre ponderada por el
		// coeficiente de congestión medio de las vías OCUPADAS DENTRO de la zona de
		// cobro. El enfoque previo (desplazamiento geométrico por ciclo) degeneraba:
		// 0.0 exacto en E0 y ~100 km/h irreal en EB. Medir en la zona (no en toda la
		// red) captura el efecto del peaje, que descongestiona el polígono mientras
		// el rerouteo desplaza tráfico a la periferia. Acotada [0.1·VEL_LIBRE, VEL_LIBRE].
		list<road> ocupadas <- roads_conectadas where
		    (each.nb_people > 0.0 and each.shape intersects zona_peaje);
		if empty(ocupadas) {   // fallback: ninguna vía ocupada en la zona → toda la red
			ocupadas <- roads_conectadas where (each.nb_people > 0.0);
		}
		float coef <- empty(ocupadas) ? 1.0 : mean(ocupadas collect each.speed_coeff);
		velocidad_media <- round(VEL_LIBRE_KMH * coef * 10.0) / 10.0;
	}

	reflex exportar_metricas when: (cycle mod INTERVALO_LOG = 0) and (cycle > 0) {
		string archivo <- OUTPUT_PATH + "E0_heterogeneo_metricas.csv";

		// BUG-2 fix: la cuota modal se calcula como SNAPSHOT de la intención actual
		// de toda la flota, no con contadores de eventos de decisión. En E0 los
		// conductores no-restringidos casi nunca deliberan (sin peaje), por lo que
		// los contadores globales count_* quedaban en ~0 y pct_ruta_directa salía 0.
		// El snapshot cuenta a esos conductores correctamente como RUTA_DIRECTA.
		list<ConductorBDI> flota <- list(ConductorBDI);
		int n_directo <- flota count (each.intencion = "RUTA_DIRECTA");
		int n_reroute <- flota count (each.intencion = "REROUTEAR");
		int n_metro   <- flota count (each.intencion = "METRO");
		int total     <- max(1, n_directo + n_reroute + n_metro);
		float pd  <- n_directo / float(total) * 100.0;
		float pr  <- n_reroute / float(total) * 100.0;
		float pm  <- n_metro   / float(total) * 100.0;

		// Desglose NSE por intención (snapshot)
		int s_directo_alto  <- flota count (each.intencion="RUTA_DIRECTA" and each.nse="ALTO");
		int s_directo_medio <- flota count (each.intencion="RUTA_DIRECTA" and each.nse="MEDIO");
		int s_directo_bajo  <- flota count (each.intencion="RUTA_DIRECTA" and each.nse="BAJO");
		int s_metro_alto    <- flota count (each.intencion="METRO" and each.nse="ALTO");
		int s_metro_medio   <- flota count (each.intencion="METRO" and each.nse="MEDIO");
		int s_metro_bajo    <- flota count (each.intencion="METRO" and each.nse="BAJO");
		int s_rerouta_alto  <- flota count (each.intencion="REROUTEAR" and each.nse="ALTO");
		int s_rerouta_medio <- flota count (each.intencion="REROUTEAR" and each.nse="MEDIO");
		int s_rerouta_bajo  <- flota count (each.intencion="REROUTEAR" and each.nse="BAJO");
		int s_restringidos  <- flota count (each.restringido_placa
		                       and minuto_actual >= RESTRICCION_INICIO
		                       and minuto_actual <= RESTRICCION_FIN);

		modal_shift_acum <- sum(EstacionMetro collect each.modal_shift_total);

		int    hh      <- int(minuto_actual / 60);
		int    mm      <- minuto_actual mod 60;
		string hora_str <- string(hh) + ":" + (mm < 10 ? "0" : "") + string(mm);

		save ["E0_HET", minuto_actual, hora_str, es_hora_pico,
		      length(ConductorBDI), velocidad_media,
		      round(pd * 10) / 10.0, round(pr * 10) / 10.0, round(pm * 10) / 10.0,
		      modal_shift_acum,
		      s_restringidos,
		      s_directo_alto,  s_directo_medio,  s_directo_bajo,
		      s_metro_alto,    s_metro_medio,    s_metro_bajo,
		      s_rerouta_alto,  s_rerouta_medio,  s_rerouta_bajo]
		to: archivo format: "csv" rewrite: false;

		count_ruta_directa <- 0; count_reroutean   <- 0; count_metro <- 0;
		count_restringidos <- 0;
		count_directo_alto  <- 0; count_directo_medio <- 0; count_directo_bajo  <- 0;
		count_metro_alto    <- 0; count_metro_medio   <- 0; count_metro_bajo    <- 0;
		count_rerouta_alto  <- 0; count_rerouta_medio <- 0; count_rerouta_bajo  <- 0;
	}

	reflex fin_sim when: minuto_actual >= hora_fin_sim {
		write "SIMULACIÓN COMPLETADA HETEROGÉNEA — vel. final: " + round(velocidad_media) + " km/h";
		do pause;
	}
}

species road {
	float capacity    <- 1 + shape.perimeter / 30;
	// Ocupación ponderada basada en el factor geométrico/vial de cada tipo de vehículo
	// BUG-velocidad fix: los agentes que se pasan al Metro dejan su auto y NO
	// congestionan la vía. Se excluyen de la ocupación para que el cambio modal
	// realmente descongestione la zona (antes seguían contando como tráfico y la
	// velocidad no se diferenciaba entre escenarios).
	float nb_people   <- 0.0 update: sum((ConductorBDI at_distance 10)
	                                 where (each.intencion != "METRO")
	                                 collect each.factor_capacidad_via);
	float speed_coeff <- 1.0 update: exp(-nb_people / capacity) min: 0.1;
	aspect default { draw shape  color: #white width: 2; }
}

species PuntoControl {
	int    id_control        <- 0;
	string nombre_acceso     <- "";
	float  tarifa_vigente    <- 0.0;
	bool   modo_peaje_activo <- false;

	// Compuerta de acceso sobre la frontera de la zona. Se "enciende" en rojo
	// cuando hay tarifa vigente (en E0 siempre 0 → queda neutra/gris).
	aspect default {
		bool activo <- tarifa_vigente > 0.0;
		rgb  c      <- activo ? rgb(220, 40, 40) : rgb(110, 120, 130);
		// Pilar vertical tipo pórtico de peaje, más alto y rojo cuando cobra.
		draw box(36, 36, (activo ? 90 : 40)) at: location color: rgb(c, 0.92) border: #white;
		draw "C" + id_control at: location + {0, 0, (activo ? 100 : 50)}
		     color: #white font: font("Arial", 13, #bold);
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

	// Ícono tipo estación: halo exterior tenue para destacar sobre la red, disco
	// con "M" (Metro de Quito), nombre como etiqueta y demanda en espera.
	aspect default {
		rgb c <- saturada ? rgb(220, 60, 60) : rgb(40, 120, 220);
		draw circle(78) at: location color: rgb(c, 0.16);
		draw circle(48) at: location color: c border: #white depth: 8;
		draw "M" at: location + {0, 0, 12} color: #white font: font("Arial", 24, #bold);
		draw nombre at: location + {0, -82, 6} color: #white font: font("Arial", 11, #bold);
		if (pasajeros_espera > 0) {
			draw ("" + pasajeros_espera + " esperan") at: location + {0, 86, 6}
			     color: (saturada ? rgb(255, 150, 150) : rgb(160, 205, 255))
			     font: font("Arial", 9, #bold);
		}
	}
}

species ConductorBDI skills: [moving] {

	// ── Atributos Generales ──────────────────────────────────────────────────
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

	// ── Atributos Heterogéneos Estructurados V2 ──────────────────────────────
	string tipo_vehiculo        <- "AUTO"; // MOTO | AUTO | SUV | BUS | CARGA
	float  factor_capacidad_via <- 1.0;
	float  tarifa_efectiva      <- 0.0;
	bool   exonerado_peaje      <- false;

	point  destino           <- nil;
	string intencion         <- "RUTA_DIRECTA";
	bool   decision_tomada   <- false;
	int    t_sin_avanzar     <- 0;
	point  pos_anterior      <- nil;
	float  dist_ultimo_ciclo <- 0.0;   // BUG-1: desplazamiento real del último ciclo (m)

	init {
		// FIX DEFINITIVO: Un solo ciclo unificado de inicialización para evitar pisar variables
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
		
		// §3.1: ~20 % de la flota con placa restringida en días hábiles (igual que EB)
		restringido_placa <- (rnd(1.0) < PCT_RESTRICCION_PLACA)
		                   and (dia_semana >= 1 and dia_semana <= 5);
		metro_accesible   <- rnd(1.0) < 0.60;
		pos_anterior      <- location;

		// Asignación de propiedades físicas y de comportamiento por tipo de vehículo
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
			restringido_placa    <- false;          // los buses no tienen restricción de placa
			nse                  <- "BAJO";
		} else if (tipo_vehiculo = "CARGA") {
			speed                <- max(10.0, speed - 40.0);
			factor_capacidad_via <- 2.5;
			metro_accesible      <- false;
			restringido_placa    <- false;          // carga: restricción de zona, no de placa
			nse                  <- "BAJO";
		}
	}

	reflex percibir {
		ask PuntoControl at_distance 300 {
			myself.tarifa_percibida <- self.tarifa_vigente;
		}

		// En E0 las tarifas serán siempre 0.0, pero se mantiene la estructura lógica
		if (exonerado_peaje) {
			tarifa_efectiva <- 0.0;
		} else {
			tarifa_efectiva <- tarifa_percibida; 
		}

		list<road> vias_cercanas <- road at_distance 200;
		if not empty(vias_cercanas) {
			int saturadas      <- length(vias_cercanas where (each.speed_coeff <= 0.5));
			nivel_congestion   <- saturadas / float(length(vias_cercanas));
		} else {
			nivel_congestion   <- 0.0;
		}
	}

	// Deliberación gatillada por congestión O por restricción de placa vigente
	// (§3.1: los restringidos deben decidir metro/rerouteo al entrar la franja,
	//  aunque no haya congestión suficiente — mismo criterio que EB).
	reflex deliberar when: not decision_tomada and (
	                   nivel_congestion >= umbral_congestion
	                   or (restringido_placa
	                       and minuto_actual >= RESTRICCION_INICIO
	                       and minuto_actual <= RESTRICCION_FIN)
	               ) {
		do decidir();
	}

	action decidir {
		// Comportamiento del transporte público masivo (Bus sigue su ruta directa pase lo que pase)
		if (tipo_vehiculo = "BUS") {
			intencion          <- "RUTA_DIRECTA";
			count_ruta_directa <- count_ruta_directa + 1;
			chart_ruta_directa <- chart_ruta_directa + 1;
			count_directo_bajo  <- count_directo_bajo + 1;
			decision_tomada    <- true;
			return;
		}

		// §3.1 Prioridad: restricción de placa vigente → no puede usar ruta directa
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN) {
			count_restringidos <- count_restringidos + 1;
			chart_restringidos <- chart_restringidos + 1;
			intencion <- metro_accesible ? "METRO" : "REROUTEAR";
			if intencion = "METRO" {
				if not empty(EstacionMetro) {
					ask (EstacionMetro closest_to self) {
						if not saturada { pasajeros_espera <- pasajeros_espera + 1; }
					}
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
		float um <- u_metro();

		if (ud >= ur and ud >= um) {
			intencion          <- "RUTA_DIRECTA";
			count_ruta_directa <- count_ruta_directa + 1;
			chart_ruta_directa <- chart_ruta_directa + 1;
			if      (nse = "ALTO")  { count_directo_alto  <- count_directo_alto  + 1; }
			else if (nse = "MEDIO") { count_directo_medio <- count_directo_medio + 1; }
			else                    { count_directo_bajo  <- count_directo_bajo  + 1; }
		} else if (um > ur and metro_accesible) {
			intencion   <- "METRO";
			count_metro <- count_metro + 1;
			chart_metro <- chart_metro + 1;
			if      (nse = "ALTO")  { count_metro_alto  <- count_metro_alto  + 1; }
			else if (nse = "MEDIO") { count_metro_medio <- count_metro_medio + 1; }
			else                    { count_metro_bajo  <- count_metro_bajo  + 1; }
			
			if not empty(EstacionMetro) {
			    ask (EstacionMetro closest_to self) {
			        if not saturada { pasajeros_espera <- pasajeros_espera + 1; }
			    }
			}
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
		return w_tiempo * (1.0 / max(1.0, speed)) + w_costo * uc
		     + w_comodidad * (0.90 * congestion_penalty);
	}

	float u_reroutear {
		float congestion_bonus <- nivel_congestion * 0.30;
		return w_tiempo * (1.0 / max(1.0, speed * 0.65)) + w_costo * 1.0
		     + w_comodidad * (0.60 + congestion_bonus);
	}

	float u_metro {
		if not metro_accesible { return 0.0; }
		float congestion_bonus <- nivel_congestion * 0.20;
		return w_tiempo * (1.0 / 12.0) + w_costo * (1.0 / COSTO_METRO)
		     + w_comodidad * (0.70 + congestion_bonus);
	}

	reflex mover when: destino != nil {
		// §3.1: si la placa está restringida y no se desvió al Metro, no circula por
		// la zona durante la franja (06:00–20:00); espera/redestina periódicamente.
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN and intencion != "METRO") {
			dist_ultimo_ciclo <- 0.0;   // inmovilizado: no se desplaza
			if (cycle mod 300 = 0) {
				list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
				destino <- any_location_in(one_of(pool));
			}
			return;
		}
		do goto target: destino on: road_network move_weights: road_weights speed: speed;

		// Desplazamiento real del ciclo, usado para detectar agentes atascados
		// (t_sin_avanzar). La velocidad media ya no se deriva de aquí (ver update_road_speed).
		dist_ultimo_ciclo <- (pos_anterior != nil) ? (location distance_to pos_anterior) : 0.0;
		if (dist_ultimo_ciclo < 1.0) {
			t_sin_avanzar <- t_sin_avanzar + 1;
		} else {
			t_sin_avanzar <- 0;
		}
		pos_anterior <- copy(location);

		if (location distance_to destino < 150 or t_sin_avanzar > 1200) {
			// §3.2 fix: NO se cuenta RUTA_DIRECTA al llegar al destino. El conteo de
			// decisiones ocurre solo en `decidir`; contar también las llegadas mezclaba
			// "eventos de decisión" con "eventos de llegada" e inflaba pct_ruta_directa.
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
		// §3.2 fix: asignar un destino no es una decisión BDI; no incrementa el contador.
		list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
		destino <- any_location_in(one_of(pool));
	}

	aspect default {
		// Color base estructural por Tipo de Vehículo
		rgb col <- #gray;
		if      (tipo_vehiculo = "MOTO")  { col <- #deepskyblue; }
		else if (tipo_vehiculo = "AUTO")  { col <- #dodgerblue;  }
		else if (tipo_vehiculo = "SUV")   { col <- #mediumpurple;}
		else if (tipo_vehiculo = "BUS")   { col <- #limegreen;   }
		else if (tipo_vehiculo = "CARGA") { col <- #sienna;      }

		// Enmascaramiento visual por Desvío Colaborativo Dinámico (BDI)
		if (decision_tomada) {
			if      (intencion = "REROUTEAR") { col <- #orange; }
			else if (intencion = "METRO")     { col <- #gold;   }
		}

		// §3.1: restringidos por placa en rojo durante la franja vigente
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN) { col <- #red; }

		// Dimensionamiento físico por Escala V2
		float sz <- 8.0;
		if      (tipo_vehiculo = "MOTO")  { sz <- 5.0;  }
		else if (tipo_vehiculo = "SUV")   { sz <- 10.0; }
		else if (tipo_vehiculo = "BUS")   { sz <- 14.0; }
		else if (tipo_vehiculo = "CARGA") { sz <- 12.0; }

		// Dentro/fuera de la zona de cobro: los de dentro van a color pleno con
		// borde blanco (foco de atención); los de fuera, atenuados, para que la
		// zona resalte y se distinga el tráfico de paso del periférico.
		bool dentro <- location intersects zona_peaje;
		if (dentro) {
			draw circle(sz) at: location + {0, 0, 5} color: col border: #white;
		} else {
			draw circle(sz) at: location + {0, 0, 5} color: rgb(col, 0.45) border: #black;
		}
	}
}

// ── Experimento EB ─────────────────────────────────────────────────────────────
experiment "Simulacion Base Heterogenea" type: gui autorun: true {

	// Categoría: Vehículos
	parameter "Motos (~15 %)"              var: NB_MOTOS   min: 0  max: 150 step: 15  category: "Vehículos";
	parameter "Autos particulares (~55 %)" var: NB_AUTOS   min: 0  max: 300 step: 25  category: "Vehículos";
	parameter "SUV / 4x4 (~15 %)"         var: NB_SUVS    min: 0  max: 150 step: 15  category: "Vehículos";
	parameter "Buses / T. público (~10 %)" var: NB_BUSES   min: 0  max: 100 step: 10  category: "Vehículos";
	parameter "Vehículos de carga (~5 %)"  var: NB_CARGAS  min: 0  max: 50  step: 5   category: "Vehículos";
	
	// Categoría: Simulación
	parameter "Día semana (1=Lun,7=Dom)"   var: dia_semana min: 1  max: 7             category: "Sim";

	// ── AGREGADO: Parámetro de Tarifa Nominal para mantener consistencia con EB ──
parameter "Tarifa AUTO pico USD [EB]" var: TARIFA_PICO_AUTO min: 0.5 max: 3.0 step: 0.25 category: "[EB nominal]";

	float minimum_cycle_duration <- 0.01;

	output synchronized: true {

		display "Mapa La Carolina — Base Heterogénea" type: 3d axes: false
		        background: rgb(22, 24, 28) toolbar: false {

			// ── Panel HUD en 3 niveles separados por divisores ───────────────────
			// NIVEL 1 (identidad) · NIVEL 2 (estado en vivo) · NIVEL 3 (leyenda).
			// Un solo acento de color (naranja = marca); color semántico solo en
			// PICO y estado de zona. Los divisores y el tamaño marcan la jerarquía.
			overlay position: {18 #px, 18 #px} size: {250 #px, 350 #px}
			        background: rgb(15, 17, 22) border: rgb(70, 75, 85) rounded: true {
				int hh <- int(minuto_actual / 60);
				int mm <- minuto_actual mod 60;
				string reloj <- (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm;

				// ── NIVEL 1 · Identidad ──────────────────────────────────────────
				draw "SMA · La Carolina" at: {14 #px, 13 #px} anchor: #top_left
				     color: #orange font: font("Arial", 15, #bold);
				draw "Escenario E0 · Baseline (sin cobro)" at: {14 #px, 33 #px} anchor: #top_left
				     color: rgb(140, 145, 155) font: font("Arial", 9, #plain);
				draw rectangle(222 #px, 1 #px) at: {125 #px, 52 #px} color: rgb(55, 60, 70);

				// ── NIVEL 2 · Estado en vivo (el reloj domina) ───────────────────
				draw reloj at: {14 #px, 60 #px} anchor: #top_left
				     color: #white font: font("Arial", 26, #bold);
				draw (es_hora_pico ? "● PICO" : "valle") at: {150 #px, 72 #px} anchor: #top_left
				     color: (es_hora_pico ? #orange : rgb(110, 115, 125))
				     font: font("Arial", 12, #bold);

				draw "VELOCIDAD" at: {14 #px, 102 #px} anchor: #top_left
				     color: rgb(130, 135, 145) font: font("Arial", 8, #bold);
				draw ("" + velocidad_media + " km/h") at: {14 #px, 115 #px} anchor: #top_left
				     color: #white font: font("Arial", 13, #bold);
				draw "ZONA" at: {140 #px, 102 #px} anchor: #top_left
				     color: rgb(130, 135, 145) font: font("Arial", 8, #bold);
				draw "LIBRE" at: {140 #px, 115 #px} anchor: #top_left
				     color: #limegreen font: font("Arial", 13, #bold);
				draw rectangle(222 #px, 1 #px) at: {125 #px, 142 #px} color: rgb(55, 60, 70);

				// ── NIVEL 3 · Leyenda ────────────────────────────────────────────
				float y <- 154 #px;
				draw "VEHÍCULOS" at: {14 #px, y} anchor: #top_left
				     color: rgb(125, 130, 140) font: font("Arial", 9, #bold);
				y <- y + 18 #px;
				loop item over: [["Moto", #deepskyblue], ["Auto", #dodgerblue], ["SUV / 4x4", #mediumpurple], ["Bus", #limegreen], ["Carga", #sienna], ["Restringido (placa)", #red]] {
					draw circle(6 #px) at: {20 #px, y} color: rgb(rgb(item[1]), 0.95);
					draw string(item[0]) at: {34 #px, y} anchor: #left_center
					     color: rgb(205, 208, 214) font: font("Arial", 10, #plain);
					y <- y + 20 #px;
				}
				y <- y + 6 #px;
				draw "DECISIÓN BDI" at: {14 #px, y} anchor: #top_left
				     color: rgb(125, 130, 140) font: font("Arial", 9, #bold);
				y <- y + 18 #px;
				loop item over: [["Reroutan (vía periférica)", #orange], ["→ Metro (modal)", #gold]] {
					draw square(11 #px) at: {20 #px, y} color: rgb(rgb(item[1]), 0.9);
					draw string(item[0]) at: {34 #px, y} anchor: #left_center
					     color: rgb(205, 208, 214) font: font("Arial", 10, #plain);
					y <- y + 20 #px;
				}
			}

			light #ambient intensity: 130;
			species road refresh: false;

			// ── Zona de cobro dibujada sobre la red: relleno tenue + frontera ──
			// Hace visible dónde empieza y termina el área de estudio (en E0 sin
			// cobro → azul neutro). Los conductores dentro de este polígono se
			// dibujan a color pleno (ver aspect de ConductorBDI).
			graphics "Zona La Carolina" {
				draw zona_peaje color: rgb(rgb(46, 109, 164), 0.10)
				     border: rgb(120, 170, 220);
				// Etiqueta discreta apoyada en el borde inferior (no flota en el centro).
				draw "ZONA LA CAROLINA" at: lbl_zona
				     anchor: #left_center color: rgb(140, 175, 215)
				     font: font("Arial", 11, #bold);
			}

			species PuntoControl;
			species EstacionMetro;
			species ConductorBDI;
		}

		display "Decisiones BDI" {
			// Dona (style: ring) con etiquetas sobre las porciones (series_label_position:
			// onchart) → el % de cada decisión se lee directamente en el gráfico, sin
			// depender solo de la leyenda lateral. Snapshot de la intención actual de la
			// flota (coincide con el CSV).
			chart "Decisiones de la flota (instantánea)" type: pie
			      background: rgb(25, 25, 25) color: #white
			      series_label_position: onchart
			      label_text_color: #black label_font: font("Arial", 12, #bold)
			      legend_font: font("Arial", 11, #plain) {
				data "Ruta directa" value: ConductorBDI count (each.intencion = "RUTA_DIRECTA") color: #dodgerblue;
				data "Reroutan"     value: ConductorBDI count (each.intencion = "REROUTEAR")    color: #orange;
				data "→ Metro"      value: ConductorBDI count (each.intencion = "METRO")        color: #gold;
			}
		}

		// NOTA: el display "Reparto modal en el tiempo" se retiró — la evolución del
		// reparto se analiza en el pipeline Python (columnas pct_* del CSV). En la
		// vista viva queda el pastel "Decisiones BDI" como instantánea.
	}
}