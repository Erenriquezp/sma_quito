/**
 * TrafficBase_LaCarolina_V2_Heterogeneo.gaml
 * Modelo SMA — Zona de cobro por congestión, Parque La Carolina, Quito
 * UCE — Sistemas Colaborativos 2026
 *
 * MODIFICACIONES (Integración V2 Heterogénea sin Restricciones):
 * 1. Remoción absoluta de la lógica "Pico y Placa" (restringido_placa, count_restringidos, etc.).
 * 2. Segmentación de la flota: Motos, Autos, SUVs, Buses y Carga.
 * 3. Cálculo de congestión vial dinámico ponderado mediante 'factor_capacidad_via'.
 * 4. Corrección del bug de doble asignación de NSE en el init de ConductorBDI.
 * 5. Ajuste en el display para reflejar la leyenda de la flota y decisiones BDI puras.
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

	// ── Peaje (Inactivo en E0) ───────────────────────────────────────────────
	float TARIFA_VALLE <- 0.00;
	
	float TARIFA_PICO_AUTO <- 2.00;
	// ── Costo referencia Metro (para función de utilidad) ────────────────────
	float COSTO_METRO <- 0.45;

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

		// Puntos de Control (Estáticos en E0 - Sin Cobro)
		create PuntoControl with: [id_control::1, nombre_acceso::"C1-NacUnidas/Amazonas", location::{1200.0, 3500.0}, tarifa_vigente::0.0, modo_peaje_activo::false];
		create PuntoControl with: [id_control::2, nombre_acceso::"C2-NacUnidas/Shyris", location::{2400.0, 3500.0}, tarifa_vigente::0.0, modo_peaje_activo::false];
		create PuntoControl with: [id_control::3, nombre_acceso::"C3-Shyris/Republica", location::{2400.0, 2700.0}, tarifa_vigente::0.0, modo_peaje_activo::false];
		create PuntoControl with: [id_control::4, nombre_acceso::"C4-Amazonas/Republica", location::{1200.0, 2700.0}, tarifa_vigente::0.0, modo_peaje_activo::false];
		create PuntoControl with: [id_control::5, nombre_acceso::"C5-6Dic/NacUnidas", location::{1800.0, 3500.0}, tarifa_vigente::0.0, modo_peaje_activo::false];

		create EstacionMetro with: [nombre::"Iñaquito", location::{1800.0, 3600.0}];
		create EstacionMetro with: [nombre::"La Carolina", location::{1800.0, 3100.0}];

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

		chart_ruta_directa <- length(ConductorBDI);

		// Configuración del CSV sin columnas de restricción de placa
		string archivo_csv <- OUTPUT_PATH + "E0_heterogeneo_metricas.csv";
		save ["escenario","minuto","hora","es_hora_pico",
		      "nb_conductores","velocidad_media_kmh",
		      "pct_ruta_directa","pct_reroutean","pct_metro","modal_shift_acum",
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

		list<ConductorBDI> activos <- ConductorBDI where (each.pos_anterior != nil);
		if empty(activos) {
			velocidad_media <- 0.0;
		} else {
			float dist_media_ciclo <- mean(activos collect (each.location distance_to each.pos_anterior));
			velocidad_media <- round(dist_media_ciclo * 0.36 * 10.0) / 10.0;
		}
	}

	reflex exportar_metricas when: (cycle mod INTERVALO_LOG = 0) and (cycle > 0) {
		string archivo <- OUTPUT_PATH + "E0_heterogeneo_metricas.csv";

		int total <- count_ruta_directa + count_reroutean + count_metro;
		float pd  <- (total > 0) ? (count_ruta_directa / float(total) * 100.0) : 0.0;
		float pr  <- (total > 0) ? (count_reroutean    / float(total) * 100.0) : 0.0;
		float pm  <- (total > 0) ? (count_metro        / float(total) * 100.0) : 0.0;

		modal_shift_acum <- sum(EstacionMetro collect each.modal_shift_total);

		int    hh      <- int(minuto_actual / 60);
		int    mm      <- minuto_actual mod 60;
		string hora_str <- string(hh) + ":" + (mm < 10 ? "0" : "") + string(mm);

		save ["E0_HET", minuto_actual, hora_str, es_hora_pico,
		      length(ConductorBDI), velocidad_media,
		      round(pd * 10) / 10.0, round(pr * 10) / 10.0, round(pm * 10) / 10.0,
		      modal_shift_acum,
		      count_directo_alto,  count_directo_medio,  count_directo_bajo,
		      count_metro_alto,    count_metro_medio,    count_metro_bajo,
		      count_rerouta_alto,  count_rerouta_medio,  count_rerouta_bajo]
		to: archivo format: "csv" rewrite: false;

		count_ruta_directa <- 0; count_reroutean   <- 0; count_metro <- 0;
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
	float nb_people   <- 0.0 update: sum(ConductorBDI at_distance 10 collect each.factor_capacidad_via);
	float speed_coeff <- 1.0 update: exp(-nb_people / capacity) min: 0.1;
	aspect default { draw (shape + 5) color: #white; }
}

species PuntoControl {
	int    id_control        <- 0;
	string nombre_acceso     <- "";
	float  tarifa_vigente    <- 0.0;
	bool   modo_peaje_activo <- false;

	aspect default {
		draw square(60) color: #limegreen border: #black depth: 8;
		draw "C" + id_control at: location + {0, 0, 10} color: #white font: font("Arial", 12, #bold);
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
		draw circle(50) color: (saturada ? #red : #royalblue) border: #white depth: 10;
		draw "M" at: location + {0, 0, 14} color: #white font: font("Arial", 16, #bold);
		draw nombre at: location + {0, -70, 6} color: #white font: font("Arial", 10, #plain);
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
			nse                  <- "BAJO";          
		} else if (tipo_vehiculo = "CARGA") {
			speed                <- max(10.0, speed - 40.0); 
			factor_capacidad_via <- 2.5;          
			metro_accesible      <- false;           
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

	// Deliberación gatillada puramente por rebasar el nivel tolerable de congestión
	reflex deliberar when: not decision_tomada and (nivel_congestion >= umbral_congestion) {
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
			
			ask (EstacionMetro closest_to self) {
				if not saturada { pasajeros_espera <- pasajeros_espera + 1; }
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
		do goto target: destino on: road_network move_weights: road_weights speed: speed;

		if (pos_anterior != nil and location distance_to pos_anterior < 1.0) {
			t_sin_avanzar <- t_sin_avanzar + 1;
		} else {
			t_sin_avanzar <- 0;
		}
		pos_anterior <- copy(location);

		if (location distance_to destino < 150 or t_sin_avanzar > 1200) {
			if intencion = "RUTA_DIRECTA" {
				count_ruta_directa <- count_ruta_directa + 1;
				chart_ruta_directa <- chart_ruta_directa + 1;
			}
			list<road> pool  <- empty(roads_conectadas) ? list(road) : roads_conectadas;
			destino          <- any_location_in(one_of(pool));
			decision_tomada  <- false;
			intencion        <- "RUTA_DIRECTA";
			tarifa_percibida <- 0.0;
			t_sin_avanzar    <- 0;
		}
	}

	reflex nuevo_destino when: destino = nil {
		list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
		destino <- any_location_in(one_of(pool));
		chart_ruta_directa <- chart_ruta_directa + 1;
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

		// Dimensionamiento físico por Escala V2
		float sz <- 18.0;
		if      (tipo_vehiculo = "MOTO")  { sz <- 12.0; }
		else if (tipo_vehiculo = "SUV")   { sz <- 22.0; }
		else if (tipo_vehiculo = "BUS")   { sz <- 32.0; }
		else if (tipo_vehiculo = "CARGA") { sz <- 28.0; }

		draw circle(sz) color: col;
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
		        background: rgb(25, 25, 25) toolbar: false {
			overlay position: {50 #px, 50 #px} size: {1 #px, 1 #px} background: #black border: #black rounded: false {
				draw "SMA — La Carolina [E0 Heterogéneo]" at: {0, 0} anchor: #top_left color: #orange
				     font: font("Arial", 16, #bold);
				int hh <- int(minuto_actual / 60);
				int mm <- minuto_actual mod 60;
				draw "Hora: " + hh + ":" + (mm < 10 ? "0" : "") + mm + (es_hora_pico ? "  ◀ PICO" : "")
				     at: {0, 40 #px} anchor: #top_left
				     color: (es_hora_pico ? #orange : #white) font: font("Arial", 12, #bold);
				draw "Vel Media: " + velocidad_media + " km/h"
				     at: {0, 70 #px} anchor: #top_left color: #white font: font("Arial", 12, #bold);

				float y <- 110 #px;
				loop item over: [["Moto", #deepskyblue], ["Auto", #dodgerblue], ["SUV / 4x4", #mediumpurple], ["Bus", #limegreen], ["Carga", #sienna]] {
					draw circle(10 #px) at: {14 #px, y} color: rgb(rgb(item[1]), 0.90);
					draw string(item[0]) at: {34 #px, y} anchor: #left_center color: #white font: font("Arial", 10, #bold);
					y <- y + 26 #px;
				}
				y <- y + 10 #px;
				draw "— Decisión Alternativa BDI —" at: {14 #px, y} anchor: #left_center color: rgb(180, 180, 180) font: font("Arial", 9, #plain);
				y <- y + 20 #px;
				loop item over: [["Reroutan (Vía Secund)", #orange], ["→ T. Metro (Modal)", #gold]] {
					draw square(18 #px) at: {14 #px, y} color: rgb(rgb(item[1]), 0.85);
					draw string(item[0]) at: {34 #px, y} anchor: #left_center color: #white font: font("Arial", 10, #bold);
					y <- y + 26 #px;
				}
			}
			light #ambient intensity: 130;
			species road refresh: false;
			species PuntoControl;
			species EstacionMetro;
			species ConductorBDI;
		}

		display "Decisiones BDI" {
			chart "Distribución de Decisiones Operativas" type: pie background: rgb(25, 25, 25) color: #white {
				data "Ruta directa" value: chart_ruta_directa color: #dodgerblue;
				data "Reroutan"     value: chart_reroutean     color: #orange;
				data "→ Metro"      value: chart_metro         color: #gold;
			}
		}

		display "Velocidad media" {
			chart "Velocidad media emergente (km/h)" type: series background: rgb(25, 25, 25) color: #white {
				data "km/h" value: velocidad_media color: #limegreen;
			}
		}
	}
}