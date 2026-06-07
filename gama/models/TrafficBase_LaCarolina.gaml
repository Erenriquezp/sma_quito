/**
 * TrafficBase_LaCarolina.gaml
 * Modelo SMA — Zona de cobro por congestión, Parque La Carolina, Quito
 * UCE — Sistemas Colaborativos 2026
 */

model TrafficBase_LaCarolina

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

	// ── Parámetros de agentes ────────────────────────────────────────────────
	int   NB_CONDUCTORES        <- 150;
	float PCT_NSE_ALTO          <- 0.15;
	float PCT_NSE_MEDIO         <- 0.45;
	float PCT_NSE_BAJO          <- 0.40;
	float WTP_NSE_ALTO          <- 3.00;
	// WTP_NSE_MEDIO subido de $1.50 a $2.25 para crear gradiente de comportamiento
	// realista en el NSE_MEDIO frente a la tarifa pico de $2.00 del Escenario B.
	// En E0 este valor no afecta el resultado (tarifa = 0) pero mantiene
	// consistencia de parámetros entre escenarios para el paper.
	float WTP_NSE_MEDIO         <- 2.25;
	float WTP_NSE_BAJO          <- 0.50;
	float PCT_RESTRICCION_PLACA <- 0.20;
	int   RESTRICCION_INICIO    <- 360;
	int   RESTRICCION_FIN       <- 1200;
	int   dia_semana            <- 1;

	// ── Peaje (activo solo en EB) ────────────────────────────────────────────
	float TARIFA_PICO  <- 2.00;
	float TARIFA_VALLE <- 0.00;

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
	int   count_restringidos <- 0;
	int   chart_ruta_directa <- 0;
	int   chart_reroutean    <- 0;
	int   chart_metro        <- 0;
	int   chart_restringidos <- 0;

	// ── Velocidad media emergente ─────────────────────────────────────────────
	// Calculada cada ciclo como promedio del speed_kmh de los conductores activos.
	// Un conductor se considera "activo" si avanzó al menos 1 m en el ciclo anterior
	// (t_sin_avanzar = 0) y no está retenido por restricción de placa.
	// Conversión: speed [m/ciclo] × (1 ciclo / 10 s) × (3600 s / 1000 m) = speed × 0.36 km/h
	float velocidad_media    <- 0.0;

	// ── Métricas de modal shift ───────────────────────────────────────────────
	// Acumulado de pasajeros que abordaron el Metro durante toda la simulación.
	// Se suma desde ambas EstacionMetro para tener el total del polígono.
	int   modal_shift_acum   <- 0;

	// ── Métricas desagregadas por NSE ────────────────────────────────────────
	// Contadores de decisiones por perfil socioeconómico en el intervalo actual.
	// Permiten calcular el índice de equidad en el paper (Δ Gini modal).
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
	int   INTERVALO_LOG      <- 90;   // cada 90 ciclos × 10 s = 15 minutos simulados
	string OUTPUT_PATH       <- "../outputs/";

	// ── Flag para escribir header solo una vez ────────────────────────────────
	// GAMA acumula filas en el CSV si rewrite:false, pero escribe el header
	// en cada llamada a save con header:true. Este flag garantiza que el
	// encabezado se escriba únicamente en el primer intervalo de exportación.
	bool   csv_header_escrito <- false;

	init {
		write "=================================================";
		write "  ESCENARIO 0 — BASELINE SIN PEAJE";
		write "  SMA Movilidad Quito — UCE 2026";
		write "=================================================";

    	create road from: road_shapefile;

		road_weights <- road as_map (each :: each.shape.perimeter);
		road_network <- as_edge_graph(road);

		// FIX DEFINITIVO: extraer el componente conexo principal del grafo.
		// as_edge_graph con shapefiles reales produce múltiples componentes aisladas.
		// goto falla silenciosamente cuando origen y destino están en componentes distintas,
		// causando que t_sin_avanzar suba indefinidamente y los agentes se congelen.
		graph main_graph   <- main_connected_component(road_network);
		roads_conectadas   <- road where (main_graph contains_edge each.shape);
		// Fallback: si el filtro por edge falla, usar todas las roads del grafo principal
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
		write "  BBOX: " + envelope(road);

		// Puntos de control — coordenadas en espacio LOCAL del shapefile
		// BBOX: x: 0..3790,  y: 0..4210
		// El Parque La Carolina ocupa aprox. x: 1200..2400, y: 2600..3800
		create PuntoControl with: [id_control::1,
		    nombre_acceso::"C1-NacUnidas/Amazonas",
		    location::{1200.0, 3500.0},
		    tarifa_vigente::0.0, modo_peaje_activo::false];

		create PuntoControl with: [id_control::2,
		    nombre_acceso::"C2-NacUnidas/Shyris",
		    location::{2400.0, 3500.0},
		    tarifa_vigente::0.0, modo_peaje_activo::false];

		create PuntoControl with: [id_control::3,
		    nombre_acceso::"C3-Shyris/Republica",
		    location::{2400.0, 2700.0},
		    tarifa_vigente::0.0, modo_peaje_activo::false];

		create PuntoControl with: [id_control::4,
		    nombre_acceso::"C4-Amazonas/Republica",
		    location::{1200.0, 2700.0},
		    tarifa_vigente::0.0, modo_peaje_activo::false];

		create PuntoControl with: [id_control::5,
		    nombre_acceso::"C5-6Dic/NacUnidas",
		    location::{1800.0, 3500.0},
		    tarifa_vigente::0.0, modo_peaje_activo::false];

		create EstacionMetro with: [nombre::"Iñaquito",
		    location::{1800.0, 3600.0}];

		create EstacionMetro with: [nombre::"La Carolina",
		    location::{1800.0, 3100.0}];

		create ConductorBDI number: NB_CONDUCTORES {
			// Fallback a toda la red si roads_conectadas estuviera vacía
			list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
			road rd  <- one_of(pool);
			location <- any_location_in(rd);
			destino  <- any_location_in(one_of(pool));
		}

		// Inicializar chart con estado inicial
		chart_ruta_directa <- length(ConductorBDI where (not each.restringido_placa));
		chart_restringidos <- length(ConductorBDI where (each.restringido_placa));

		// Limpiar el CSV al inicio de cada run para evitar acumulación entre ejecuciones.
		// Se escribe solo el encabezado; los datos se añaden en exportar_metricas.
		string archivo_csv <- OUTPUT_PATH + "E0_run1_metricas.csv";
		save ["escenario","minuto","hora","es_hora_pico",
		      "nb_conductores",
		      "velocidad_media_kmh",
		      "pct_ruta_directa","pct_reroutean","pct_metro",
		      "modal_shift_acum",
		      "recaudacion_acum_usd","nb_restringidos_placa",
		      "directo_nse_alto","directo_nse_medio","directo_nse_bajo",
		      "metro_nse_alto","metro_nse_medio","metro_nse_bajo",
		      "rerouta_nse_alto","rerouta_nse_medio","rerouta_nse_bajo"]
		to: archivo_csv format: "csv" rewrite: true;
		csv_header_escrito <- true;

		write "  Conductores: " + NB_CONDUCTORES;
		write "  NSE ALTO: "  + length(ConductorBDI where (each.nse = "ALTO"));
		write "  NSE MEDIO: " + length(ConductorBDI where (each.nse = "MEDIO"));
		write "  NSE BAJO: "  + length(ConductorBDI where (each.nse = "BAJO"));
		write "  Placa restringida: " + length(ConductorBDI where (each.restringido_placa));
		write "=================================================";
	}

	// FIX: calcular minuto_actual desde el cycle y el step, no desde time/60
	// cycle cuenta los pasos de simulación; step = 10 s → cada ciclo avanza 10 s = 1/6 min
	reflex avanzar_reloj {
		minuto_actual <- hora_inicio_sim + int(cycle * step / 60.0);
		es_hora_pico  <-
			(minuto_actual >= HORA_PICO_MAT_INICIO and minuto_actual <= HORA_PICO_MAT_FIN) or
			(minuto_actual >= HORA_PICO_VES_INICIO and minuto_actual <= HORA_PICO_VES_FIN);
	}

	reflex update_road_speed {
		road_weights <- road as_map (each :: each.shape.perimeter / each.speed_coeff);
		road_network <- road_network with_weights road_weights;

		// ── Velocidad EFECTIVA de desplazamiento ─────────────────────────────
		// Calcula la velocidad como distancia real recorrida en el ciclo anterior,
		// no como promedio de speed intrínseca del agente.
		// Conversión: distancia [m/ciclo] × 0.36 = km/h  (step=10s)
		list<ConductorBDI> activos <- ConductorBDI where (
			each.pos_anterior != nil
			and not (each.restringido_placa
			         and minuto_actual >= RESTRICCION_INICIO
			         and minuto_actual <= RESTRICCION_FIN)
		);
		if empty(activos) {
			velocidad_media <- 0.0;
		} else {
			float dist_media_ciclo <- mean(activos collect
			    (each.location distance_to each.pos_anterior));
			velocidad_media <- round(dist_media_ciclo * 0.36 * 10.0) / 10.0;
		}
	}

	// Exporta una fila al CSV cada INTERVALO_LOG ciclos (= 15 min simulados).
	// El archivo fue creado con encabezado en init, aquí solo se añaden filas.
	reflex exportar_metricas when: (cycle mod INTERVALO_LOG = 0) and (cycle > 0) {
		string archivo <- OUTPUT_PATH + "E0_run1_metricas.csv";

		// Totales del intervalo
		int total <- count_ruta_directa + count_reroutean + count_metro;
		float pd  <- (total > 0) ? (count_ruta_directa / float(total) * 100.0) : 0.0;
		float pr  <- (total > 0) ? (count_reroutean    / float(total) * 100.0) : 0.0;
		float pm  <- (total > 0) ? (count_metro        / float(total) * 100.0) : 0.0;

		// Modal shift acumulado: suma de pasajeros que abordaron el Metro
		modal_shift_acum <- sum(EstacionMetro collect each.modal_shift_total);

		int    hh      <- int(minuto_actual / 60);
		int    mm      <- minuto_actual mod 60;
		string hora_str <- string(hh) + ":" + (mm < 10 ? "0" : "") + string(mm);

		save ["E0", minuto_actual, hora_str, es_hora_pico,
		      length(ConductorBDI),
		      velocidad_media,
		      round(pd * 10) / 10.0,
		      round(pr * 10) / 10.0,
		      round(pm * 10) / 10.0,
		      modal_shift_acum,
		      round(recaudacion_acum * 100) / 100.0,
		      count_restringidos,
		      count_directo_alto,  count_directo_medio,  count_directo_bajo,
		      count_metro_alto,    count_metro_medio,    count_metro_bajo,
		      count_rerouta_alto,  count_rerouta_medio,  count_rerouta_bajo]
		to: archivo format: "csv" rewrite: false;

		// Resetear contadores del intervalo (acumulados se mantienen)
		count_ruta_directa <- 0; count_reroutean   <- 0;
		count_metro        <- 0; count_restringidos <- 0;
		count_directo_alto  <- 0; count_directo_medio <- 0; count_directo_bajo  <- 0;
		count_metro_alto    <- 0; count_metro_medio   <- 0; count_metro_bajo    <- 0;
		count_rerouta_alto  <- 0; count_rerouta_medio <- 0; count_rerouta_bajo  <- 0;
	}

	reflex fin_sim when: minuto_actual >= hora_fin_sim {
		write "SIMULACIÓN COMPLETADA — vel. final: " + round(velocidad_media) + " km/h";
		do pause;
	}
}

species road {
	float capacity    <- 1 + shape.perimeter / 30;
	// FIX: at_distance 1 era demasiado pequeño para coordenadas proyectadas (metros)
	int   nb_people   <- 0 update: length(ConductorBDI at_distance 10);
	float speed_coeff <- 1.0 update: exp(-nb_people / capacity) min: 0.1;
	aspect default { draw (shape + 5) color: #white; }
}

species PuntoControl {
	int    id_control        <- 0;
	string nombre_acceso     <- "";
	float  tarifa_vigente    <- 0.0;
	bool   modo_peaje_activo <- false;

	// [EB] Descomentar en EB_PeajeHorario.gaml
	// reflex cobrar when: modo_peaje_activo {
	//     bool pico <- (minuto_actual>=HORA_PICO_MAT_INICIO and minuto_actual<=HORA_PICO_MAT_FIN)
	//              or (minuto_actual>=HORA_PICO_VES_INICIO  and minuto_actual<=HORA_PICO_VES_FIN);
	//     tarifa_vigente <- pico ? TARIFA_PICO : TARIFA_VALLE;
	// }

	aspect default {
		draw square(60) color: (modo_peaje_activo ? #red : #limegreen) border: #black depth: 8;
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
		// FIX: usar ciclos en lugar de minuto_actual mod 5 para trigger
		// 30 ciclos × 10 s = 300 s ≈ 5 minutos simulados
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

	// ── Creencias ─────────────────────────────────────────────────────────
	string nse               <- "MEDIO";
	float  wtp               <- 1.50;
	float  w_tiempo          <- 0.35;
	float  w_costo           <- 0.35;
	float  w_comodidad       <- 0.30;
	bool   restringido_placa <- false;
	bool   metro_accesible   <- false;
	float  tarifa_percibida  <- 0.0;
	// FIX: speed en m/ciclo (step=10s). 5 m/s × 10s = 50 m/ciclo base.
	// Rango: 30–110 m/ciclo ≈ 11–40 km/h
	float  speed             <- (rnd(5.0) + 3.0) * 10.0;

	// ── Percepción de congestión ──────────────────────────────────────────
	// nivel_congestion ∈ [0.0, 1.0]: promedio de ocupación de vías cercanas.
	// 0.0 = vías libres; 1.0 = todas las vías cercanas al límite de capacidad.
	// Se recalcula cada ciclo para que el agente "sienta" el tráfico en tiempo real.
	float  nivel_congestion  <- 0.0;

	// umbral_congestion: sensibilidad individual al tráfico.
	// NSE ALTO → más impaciente (0.40); NSE BAJO → más tolerante (0.70).
	// El agente delibera cuando nivel_congestion supera su umbral personal.
	float  umbral_congestion <- 0.55;

	// ── Estado ────────────────────────────────────────────────────────────
	point  destino           <- nil;
	string intencion         <- "RUTA_DIRECTA";
	bool   decision_tomada   <- false;
	int    t_sin_avanzar     <- 0;
	point  pos_anterior      <- nil;

	init {
		float r <- rnd(1.0);
		if (r < PCT_NSE_ALTO) {
			nse <- "ALTO";  wtp <- WTP_NSE_ALTO;
			w_tiempo <- 0.35; w_costo <- 0.15; w_comodidad <- 0.50;
			speed <- speed + 30.0;   // +3 m/s → +30 m/ciclo
			// NSE ALTO: impaciente, reacciona antes a la congestión
			umbral_congestion <- 0.40;
		} else if (r < PCT_NSE_ALTO + PCT_NSE_MEDIO) {
			nse <- "MEDIO"; wtp <- WTP_NSE_MEDIO;
			w_tiempo <- 0.35; w_costo <- 0.35; w_comodidad <- 0.30;
			// NSE MEDIO: sensibilidad estándar
			umbral_congestion <- 0.55;
		} else {
			nse <- "BAJO";  wtp <- WTP_NSE_BAJO;
			w_tiempo <- 0.20; w_costo <- 0.65; w_comodidad <- 0.15;
			speed <- max(10.0, speed - 10.0);  // mín 1 m/s → 10 m/ciclo
			// NSE BAJO: tolera más el tráfico (sin costo de alternativas)
			umbral_congestion <- 0.70;
		}
		restringido_placa <- (rnd(1.0) < PCT_RESTRICCION_PLACA)
		                   and (dia_semana >= 1 and dia_semana <= 5);
		metro_accesible   <- rnd(1.0) < 0.60;
		pos_anterior      <- location;
	}

	// ── Percepción ────────────────────────────────────────────────────────
	// Se ejecuta siempre, incluso cuando ya se tomó una decisión,
	// para que nivel_congestion esté actualizado en cada ciclo.
	reflex percibir {
		// 1. Tarifa del peaje (solo relevante en EB; en E0 siempre será 0.0)
		ask PuntoControl at_distance 300 {
			myself.tarifa_percibida <- self.tarifa_vigente;
		}

		// 2. Congestión percibida: fracción de vías cercanas saturadas.
		//    Se miden las road dentro de 200 unidades del agente.
		//    speed_coeff ≤ 0.5 indica que la vía está a más del 50% de saturación.
		list<road> vias_cercanas <- road at_distance 200;
		if not empty(vias_cercanas) {
			int saturadas      <- length(vias_cercanas where (each.speed_coeff <= 0.5));
			nivel_congestion   <- saturadas / float(length(vias_cercanas));
		} else {
			nivel_congestion   <- 0.0;
		}
	}

	// ── Deliberación BDI ──────────────────────────────────────────────────
	// Trigger 1 — Peaje activo: el agente percibe una tarifa > 0 (escenario EB).
	// Trigger 2 — Congestión alta: el nivel supera el umbral personal del agente.
	// En E0 solo el trigger 2 se activa; en EB ambos pueden coincidir.
	reflex deliberar when: not decision_tomada
	                   and (tarifa_percibida > 0 or nivel_congestion >= umbral_congestion) {
		do decidir();
	}

	action decidir {
		// Prioridad 1: restricción de placa vigente
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN) {
			count_restringidos <- count_restringidos + 1;
			chart_restringidos <- chart_restringidos + 1;
			intencion <- metro_accesible ? "METRO" : "REROUTEAR";
			// Contabilizar desvío forzado por NSE
			if intencion = "METRO" {
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

		// Prioridad 2: función de utilidad multi-criterio
		float ud <- u_directa();
		float ur <- u_reroutear();
		float um <- u_metro();

		if (ud >= ur and ud >= um) {
			intencion          <- "RUTA_DIRECTA";
			count_ruta_directa <- count_ruta_directa + 1;
			chart_ruta_directa <- chart_ruta_directa + 1;
			recaudacion_acum   <- recaudacion_acum + tarifa_percibida;
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

	// u_directa: utilidad de seguir la ruta original.
	// En E0 (sin peaje): uc = 1.0 → costo neutral.
	// En EB (con peaje): uc = 1/tarifa → baja si la tarifa sube.
	// La congestión penaliza mediante speed real del agente.
	float u_directa {
		if tarifa_percibida > wtp { return -0.5; }
		float uc <- (tarifa_percibida > 0) ? (1.0 / tarifa_percibida) : 1.0;
		// Penalización adicional por congestión percibida
		float congestion_penalty <- 1.0 - (nivel_congestion * 0.5);
		return w_tiempo * (1.0 / max(1.0, speed)) + w_costo * uc
		     + w_comodidad * (0.90 * congestion_penalty);
	}

	// u_reroutear: utilidad de tomar una ruta alternativa más larga.
	// La congestión alta lo hace más atractivo (evita el embotellamiento).
	float u_reroutear {
		float congestion_bonus <- nivel_congestion * 0.30;
		return w_tiempo * (1.0 / max(1.0, speed * 0.65)) + w_costo * 1.0
		     + w_comodidad * (0.60 + congestion_bonus);
	}

	// u_metro: utilidad del transporte público.
	// La congestión alta lo hace más atractivo para quienes tienen acceso.
	float u_metro {
		if not metro_accesible { return 0.0; }
		float congestion_bonus <- nivel_congestion * 0.20;
		return w_tiempo * (1.0 / 12.0) + w_costo * (1.0 / COSTO_METRO)
		     + w_comodidad * (0.70 + congestion_bonus);
	}

	// ── Movimiento ────────────────────────────────────────────────────────
	reflex mover when: destino != nil {
		// Agente restringido por placa: cambia destino y espera
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN and intencion != "METRO") {
			if (cycle mod 300 = 0) {
				list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
				destino <- any_location_in(one_of(pool));
			}
			return;
		}

		do goto target: destino on: road_network move_weights: road_weights speed: speed;

		// Detectar atasco: no avanzó significativamente en este ciclo
		// Umbral: menos de 1 m (agente realmente inmóvil, no solo lento)
		if (pos_anterior != nil and location distance_to pos_anterior < 1.0) {
			t_sin_avanzar <- t_sin_avanzar + 1;
		} else {
			t_sin_avanzar <- 0;
		}
		pos_anterior <- copy(location);

		// Llegó al destino (dentro de 150 m) o lleva 1200 ciclos sin avanzar (20 min sim)
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
		rgb col <- #gray;
		if      (intencion = "RUTA_DIRECTA") { col <- #dodgerblue; }
		else if (intencion = "REROUTEAR")    { col <- #orange;     }
		else if (intencion = "METRO")        { col <- #limegreen;  }
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN) { col <- #red; }
		draw circle(20) color: col;
	}
}

experiment "Experiment traffic" type: gui autorun: true {

	parameter "Conductores"              var: NB_CONDUCTORES min: 50  max: 500 step: 50   category: "Sim";
	parameter "Día semana (1=Lun,7=Dom)" var: dia_semana     min: 1   max: 7              category: "Sim";
	parameter "Tarifa pico USD [EB]"     var: TARIFA_PICO    min: 0.0 max: 3.0 step: 0.25 category: "[EB]";

	float minimum_cycle_duration <- 0.01;

	output synchronized: true {

		display "Mapa La Carolina" type: 3d axes: false
		        background: rgb(25, 25, 25) toolbar: false {
			overlay position: {50 #px, 50 #px} size: {1 #px, 1 #px} background: #black border: #black rounded: false {
				draw "SMA — La Carolina" at: {0, 0} anchor: #top_left color: #white
				     font: font("Arial", 16, #bold);
				int hh <- int(minuto_actual / 60);
				int mm <- minuto_actual mod 60;
				draw "Hora: " + hh + ":" + (mm < 10 ? "0" : "") + mm + (es_hora_pico ? "  ◀ PICO" : "")
				     at: {0, 40 #px} anchor: #top_left
				     color: (es_hora_pico ? #orange : #white) font: font("Arial", 12, #bold);
				draw "Vel: " + round(velocidad_media) + " km/h"
				     at: {0, 70 #px} anchor: #top_left color: #white font: font("Arial", 12, #bold);

				float y <- 110 #px;
				loop lbl over: ["Ruta directa", "Reroutan", "→ Metro", "Restringidos (placa)"] {
					rgb c <- #red;
					if      (lbl = "Ruta directa") { c <- #dodgerblue; }
					else if (lbl = "Reroutan")     { c <- #orange;     }
					else if (lbl = "→ Metro")      { c <- #limegreen;  }
					draw square(28 #px) at: {14 #px, y} color: rgb(c, 0.85);
					draw lbl at: {48 #px, y} anchor: #left_center color: #white font: font("Arial", 11, #bold);
					y <- y + 36 #px;
				}
				y <- y + 16 #px;
				loop lbl over: ["Vías", "Control (sin cobro)", "Control (cobrando)", "Estación Metro"] {
					rgb c <- #royalblue;
					if      (lbl = "Vías")                { c <- #white;    }
					else if (lbl = "Control (sin cobro)") { c <- #limegreen; }
					else if (lbl = "Control (cobrando)")  { c <- #red;       }
					draw square(28 #px) at: {14 #px, y} color: rgb(c, 0.85);
					draw lbl at: {48 #px, y} anchor: #left_center color: #white font: font("Arial", 11, #bold);
					y <- y + 36 #px;
				}
			}
			light #ambient intensity: 130;
			species road         refresh: false;
			species PuntoControl;
			species EstacionMetro;
			species ConductorBDI;
		}

		display "Flujo vehicular" {
			chart "Conductores en la red" type: series background: rgb(25, 25, 25) color: #white {
				data "Activos"
				     value: length(ConductorBDI where (each.t_sin_avanzar < 300
				             and not (each.restringido_placa
				             and minuto_actual >= RESTRICCION_INICIO
				             and minuto_actual <= RESTRICCION_FIN)))
				     color: #dodgerblue;
				data "Restringidos (placa)"
				     value: length(ConductorBDI where (each.restringido_placa
				             and minuto_actual >= RESTRICCION_INICIO
				             and minuto_actual <= RESTRICCION_FIN))
				     color: #red;
			}
		}

		display "Decisiones BDI" {
			chart "Distribución de decisiones" type: pie background: rgb(25, 25, 25) color: #white {
				data "Ruta directa" value: chart_ruta_directa color: #dodgerblue;
				data "Reroutan"     value: chart_reroutean     color: #orange;
				data "→ Metro"      value: chart_metro         color: #limegreen;
				data "Restringidos" value: chart_restringidos  color: #red;
			}
		}

		display "Velocidad media" {
			chart "Velocidad media (km/h)" type: series background: rgb(25, 25, 25) color: #white {
				data "km/h" value: velocidad_media color: #limegreen;
			}
		}
	}
}
