/**
 * EB_PeajeHorario.gaml
 * Modelo SMA — Escenario B: Peaje por franja horaria (modelo Londres)
 * Zona de cobro por congestión, Parque La Carolina, Quito
 * UCE — Sistemas Colaborativos 2026
 *
 * Diferencias respecto a TrafficBase_LaCarolina.gaml (E0):
 *   1. PuntoControl activa reflex cobrar → tarifa_vigente oscila $0 / $1.50–$2.00
 *   2. Franja de cobro: 07:00–10:00 y 17:00–20:00 (hora pico, modelo Londres)
 *   3. CSV de salida independiente: EB_run1_metricas.csv
 *   4. Display adicional: Recaudación acumulada y distribución NSE
 *   5. GestorAMT BDI activo: ajusta tarifas dinámicamente según densidad/velocidad
 *
 * Fixes aplicados (v2):
 *   FIX-1  ask EstacionMetro: guardado con not empty() para evitar nil agent
 *   FIX-2  GestorAMT vs cobrar: reflex cobrar solo actúa cuando GESTOR_ACTIVO=false
 *            o en el ciclo inicial; el gestor escribe directamente tarifa_vigente
 *   FIX-3  NB_CONDUCTORES default sube a 300 para activar deliberación BDI
 *   FIX-4  reflex deliberar añade trigger periódico en hora pico (cada 60 ciclos)
 *            para que agentes sin congestion suficiente deliberen en franja cobro
 *   FIX-5  Encabezado CSV protegido con flag csv_header_escrito (igual que E0)
 *   FIX-6  Nombre estación norte corregido: "La Carolina" → "El Labrador" (SMA.md §7.1)
 *
 * Hipótesis a contrastar (SMA.md §2.3):
 *   La zona de cobro reduce el flujo vehicular ≥ 20 % respecto al E0,
 *   incrementa el modal shift al Metro y no genera desplazamiento periférico crítico.
 */

model EB_PeajeHorario

global {

	file road_shapefile <- file("../includes/red_vial_la_carolina.shp");
	geometry shape      <- envelope(road_shapefile);
	float step          <- 10 #s;

	// ── Reloj ────────────────────────────────────────────────────────────────
	int hora_inicio_sim      <- 360;    // 06:00
	int hora_fin_sim         <- 1320;   // 22:00
	int minuto_actual        <- 360;
	// Franja de cobro mañana: 07:00–10:00 (modelo London Congestion Charge)
	int HORA_PICO_MAT_INICIO <- 420;
	int HORA_PICO_MAT_FIN    <- 600;
	// Franja de cobro tarde: 17:00–20:00
	int HORA_PICO_VES_INICIO <- 1020;
	int HORA_PICO_VES_FIN    <- 1200;
	bool es_hora_pico        <- false;

	// ── Parámetros de agentes ────────────────────────────────────────────────
	// FIX-3: default subido a 300 para garantizar deliberación BDI activa.
	// Con 150 agentes la densidad no supera umbral_congestion en la mayoría de vías.
	// 300 agentes producen ~0.6–0.75 en nivel_congestion durante hora pico.
	int NB_MOTOS  <- 45;    // ~15 % de la flota
	int NB_AUTOS  <- 165;   // ~55 %
	int NB_SUVS   <- 45;    // ~15 %
	int NB_BUSES  <- 30;    // ~10 % — siempre exonerados del peaje (SMA.md §7.2)
	int NB_CARGAS <- 15;    // ~5 %
	float PCT_NSE_ALTO          <- 0.15;
	float PCT_NSE_MEDIO         <- 0.45;
	float PCT_NSE_BAJO          <- 0.40;
	float WTP_NSE_ALTO          <- 3.00;
	// WTP_NSE_MEDIO en $2.25: con tarifa pico de $2.00 el NSE_MEDIO exhibe
	// comportamiento mixto (algunos pagan, otros reroutan) — efecto Londres.
	float WTP_NSE_MEDIO         <- 2.25;
	float WTP_NSE_BAJO          <- 0.50;
	float PCT_RESTRICCION_PLACA <- 0.20;
	int   RESTRICCION_INICIO    <- 360;
	int   RESTRICCION_FIN       <- 1200;
	int   dia_semana            <- 1;

	// ── Parámetros de peaje EB ────────────────────────────────────────────────
	// ── Tarifas diferenciadas por tipo de vehículo (hora pico) ─────────────────
	float TARIFA_PICO_AUTO  <- 2.00;   // Auto particular — tarifa base (slider principal)
	float TARIFA_PICO_MOTO  <- 0.00;   // Moto — exonerada (propuesta DMQ)
	float TARIFA_PICO_SUV   <- 2.00;   // SUV/4x4 — por defecto igual al auto
	float TARIFA_PICO_CARGA <- 3.00;   // Vehículo de carga — mayor impacto vial
	float TARIFA_VALLE   <- 0.00;   // USD — fuera de franja
	bool  PEAJE_ACTIVO   <- true;

	// ── Control del GestorAMT ─────────────────────────────────────────────────
	// FIX-2: cuando GESTOR_ACTIVO = true, el reflex cobrar del PuntoControl
	// NO sobreescribe tarifa_vigente; el gestor tiene control exclusivo.
	// Cuando GESTOR_ACTIVO = false, el reflex cobrar aplica tarifa_base directamente.
	bool  GESTOR_ACTIVO  <- true;

	// ── Costo referencia Metro ────────────────────────────────────────────────
	float COSTO_METRO <- 0.45;

	// ── Red vial ─────────────────────────────────────────────────────────────
	graph road_network;
	map<road, float> road_weights;
	list<road> roads_conectadas <- [];

	// ── Métricas globales ────────────────────────────────────────────────────
	int   count_ruta_directa  <- 0;
	int   count_reroutean     <- 0;
	int   count_metro         <- 0;
	int   count_restringidos  <- 0;
	int   chart_ruta_directa  <- 0;
	int   chart_reroutean     <- 0;
	int   chart_metro         <- 0;
	int   chart_restringidos  <- 0;

	float velocidad_media     <- 0.0;
	int   modal_shift_acum    <- 0;
	float recaudacion_acum    <- 0.0;

	// Métricas desagregadas por NSE (intervalo actual)
	int   count_directo_alto  <- 0;
	int   count_directo_medio <- 0;
	int   count_directo_bajo  <- 0;
	int   count_metro_alto    <- 0;
	int   count_metro_medio   <- 0;
	int   count_metro_bajo    <- 0;
	int   count_rerouta_alto  <- 0;
	int   count_rerouta_medio <- 0;
	int   count_rerouta_bajo  <- 0;

	int    INTERVALO_LOG      <- 90;
	string OUTPUT_PATH        <- "../outputs/";

	// FIX-5: flag para escribir encabezado CSV solo una vez (igual que E0)
	bool   csv_header_escrito <- false;

	init {
		write "=================================================";
		write "  ESCENARIO B — PEAJE POR FRANJA HORARIA";
		write "  Tarifa pico AUTO: $" + TARIFA_PICO_AUTO
		    + " | MOTO: $" + TARIFA_PICO_MOTO
		    + " | SUV: $"  + TARIFA_PICO_SUV
		    + " | CARGA: $"+ TARIFA_PICO_CARGA + " USD";
		write "  Franjas: 07:00-10:00 y 17:00-20:00";
		write "  SMA Movilidad Quito — UCE 2026";
		write "=================================================";

		create road from: road_shapefile;

		road_weights <- road as_map (each :: each.shape.perimeter);
		road_network <- as_edge_graph(road);

		graph main_graph  <- main_connected_component(road_network);
		roads_conectadas  <- road where (main_graph contains_edge each.shape);
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

		// ── Puntos de control con peaje ACTIVO ───────────────────────────────
		create PuntoControl with: [id_control::1,
		    nombre_acceso::"C1-NacUnidas/Amazonas",
		    location::{1200.0, 3500.0},
		    tarifa_vigente::0.0, modo_peaje_activo::true];

		create PuntoControl with: [id_control::2,
		    nombre_acceso::"C2-NacUnidas/Shyris",
		    location::{2400.0, 3500.0},
		    tarifa_vigente::0.0, modo_peaje_activo::true];

		create PuntoControl with: [id_control::3,
		    nombre_acceso::"C3-Shyris/Republica",
		    location::{2400.0, 2700.0},
		    tarifa_vigente::0.0, modo_peaje_activo::true];

		create PuntoControl with: [id_control::4,
		    nombre_acceso::"C4-Amazonas/Republica",
		    location::{1200.0, 2700.0},
		    tarifa_vigente::0.0, modo_peaje_activo::true];

		create PuntoControl with: [id_control::5,
		    nombre_acceso::"C5-6Dic/NacUnidas",
		    location::{1800.0, 3500.0},
		    tarifa_vigente::0.0, modo_peaje_activo::true];

		// ── Estaciones Metro ─────────────────────────────────────────────────
		// FIX-6: estación sur = Iñaquito, estación norte = El Labrador (SMA.md §7.1)
		create EstacionMetro with: [nombre::"Iñaquito",
		    location::{1800.0, 2800.0}];
		create EstacionMetro with: [nombre::"El Labrador",
		    location::{1800.0, 3700.0}];

		// ── GestorAMT BDI ────────────────────────────────────────────────────
		create GestorAMT;

		// ── Conductores BDI ──────────────────────────────────────────────────
		//— creación por tipo de vehículo ──────────────────────────────────
			list<road> road_pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
			
			create ConductorBDI number: NB_MOTOS {
			    tipo_vehiculo <- "MOTO";
			    road rd <- one_of(road_pool);
			    location <- any_location_in(rd);
			    destino  <- any_location_in(one_of(road_pool));
			}
			create ConductorBDI number: NB_AUTOS {
			    tipo_vehiculo <- "AUTO";
			    road rd <- one_of(road_pool);
			    location <- any_location_in(rd);
			    destino  <- any_location_in(one_of(road_pool));
			}
			create ConductorBDI number: NB_SUVS {
			    tipo_vehiculo <- "SUV";
			    road rd <- one_of(road_pool);
			    location <- any_location_in(rd);
			    destino  <- any_location_in(one_of(road_pool));
			}
			create ConductorBDI number: NB_BUSES {
			    tipo_vehiculo <- "BUS";
			    road rd <- one_of(road_pool);
			    location <- any_location_in(rd);
			    destino  <- any_location_in(one_of(road_pool));
			}
			create ConductorBDI number: NB_CARGAS {
			    tipo_vehiculo <- "CARGA";
			    road rd <- one_of(road_pool);
			    location <- any_location_in(rd);
			    destino  <- any_location_in(one_of(road_pool));
			}

		chart_ruta_directa <- length(ConductorBDI where (not each.restringido_placa));
		chart_restringidos <- length(ConductorBDI where (each.restringido_placa));
		

		// FIX-5: crear CSV con encabezado una sola vez
		string archivo_csv <- OUTPUT_PATH + "EB_run1_metricas.csv";
		save ["escenario","minuto","hora","es_hora_pico","tarifa_vigente_usd",
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
		

		write "  Total conductores: " + length(ConductorBDI);
		write "  Motos: "  + NB_MOTOS  + " | Autos: " + NB_AUTOS
		    + " | SUV: "  + NB_SUVS   + " | Buses: " + NB_BUSES
		    + " | Carga: " + NB_CARGAS;
		write "  NSE ALTO: "  + length(ConductorBDI where (each.nse = "ALTO"));
		write "  NSE MEDIO: " + length(ConductorBDI where (each.nse = "MEDIO"));
		write "  NSE BAJO: "  + length(ConductorBDI where (each.nse = "BAJO"));
		write "  Placa restringida: " + length(ConductorBDI where (each.restringido_placa));
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

	reflex exportar_metricas when: (cycle mod INTERVALO_LOG = 0) and (cycle > 0) {
		string archivo <- OUTPUT_PATH + "EB_run1_metricas.csv";

		int total  <- count_ruta_directa + count_reroutean + count_metro;
		float pd   <- (total > 0) ? (count_ruta_directa / float(total) * 100.0) : 0.0;
		float pr   <- (total > 0) ? (count_reroutean    / float(total) * 100.0) : 0.0;
		float pm   <- (total > 0) ? (count_metro        / float(total) * 100.0) : 0.0;

		modal_shift_acum <- sum(EstacionMetro collect each.modal_shift_total);

		// Tarifa vigente: tomar del primer control activo; si no hay, 0.0
		float tarifa_ahora <- empty(PuntoControl where each.modo_peaje_activo)
		    ? 0.0
		    : first(PuntoControl where each.modo_peaje_activo).tarifa_vigente;

		int    hh       <- int(minuto_actual / 60);
		int    mm_      <- minuto_actual mod 60;
		string hora_str <- string(hh) + ":" + (mm_ < 10 ? "0" : "") + string(mm_);

		save ["EB", minuto_actual, hora_str, es_hora_pico,
		      round(tarifa_ahora * 100) / 100.0,
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

		count_ruta_directa <- 0; count_reroutean   <- 0;
		count_metro        <- 0; count_restringidos <- 0;
		count_directo_alto  <- 0; count_directo_medio <- 0; count_directo_bajo  <- 0;
		count_metro_alto    <- 0; count_metro_medio   <- 0; count_metro_bajo    <- 0;
		count_rerouta_alto  <- 0; count_rerouta_medio <- 0; count_rerouta_bajo  <- 0;
	}

	reflex fin_sim when: minuto_actual >= hora_fin_sim {
		write "SIMULACIÓN EB COMPLETADA";
		write "  Recaudación total: $" + round(recaudacion_acum * 100) / 100.0 + " USD";
		write "  Modal shift Metro: " + modal_shift_acum + " pasajeros";
		write "  Velocidad final:   " + velocidad_media + " km/h";
		do pause;
	}
}

// ── Red vial ──────────────────────────────────────────────────────────────────
species road {
	float capacity    <- 1 + shape.perimeter / 30;
	float nb_people   <- 0.0 update: sum(ConductorBDI at_distance 10
                                     collect each.factor_capacidad_via);
	float speed_coeff <- 1.0 update: exp(-nb_people / capacity) min: 0.1;
	aspect default { draw shape  color: #white width: 2; }
}

// ── Punto de control con cobro activo ─────────────────────────────────────────
species PuntoControl {
	int    id_control        <- 0;
	string nombre_acceso     <- "";
	float  tarifa_vigente    <- 0.0;
	bool   modo_peaje_activo <- false;

	// tarifa_base: tarifa que corresponde por franja horaria pura (sin gestor).
float  tarifa_base <- 0.0 update: (es_hora_pico ? TARIFA_PICO_AUTO : TARIFA_VALLE);

	// FIX-2: el reflex cobrar solo aplica tarifa_base cuando el GestorAMT está
	// DESACTIVADO. Cuando GESTOR_ACTIVO = true, el gestor escribe tarifa_vigente
	// directamente mediante ask, y este reflex no interfiere.
	// Excepción: fuera de hora pico con gestor activo, se fuerza tarifa 0.0
	// porque el gestor solo delibera en días hábiles y puede no haber bajado aún.
	reflex cobrar when: modo_peaje_activo and PEAJE_ACTIVO
	                and (dia_semana >= 1 and dia_semana <= 5) {
		if not GESTOR_ACTIVO {
			// Modo tarifa fija por franja: el PuntoControl gestiona directamente
			tarifa_vigente <- tarifa_base;
		} else {
			// Modo gestor activo: fuera de hora pico forzar 0.0 si el gestor
			// aún no intervino (evita que la tarifa quede "colgada" en valor
			// anterior al cruzar el límite de la franja horaria)
			if not es_hora_pico {
				tarifa_vigente <- 0.0;
			}
			// En hora pico: el gestor ya habrá escrito tarifa_vigente en su
			// reflex deliberar. No sobreescribir aquí.
		}
	}

	// Fuera de días hábiles el peaje no cobra (independiente del gestor)
	reflex cobrar_fin_semana when: modo_peaje_activo
	                          and (dia_semana = 6 or dia_semana = 7) {
		tarifa_vigente <- 0.0;
	}

	aspect default {
		rgb col <- (modo_peaje_activo and tarifa_vigente > 0) ? #red : #limegreen;
		draw square(60) color: col border: #black depth: 8;
		draw "C" + id_control at: location + {0, 0, 10}
		     color: #white font: font("Arial", 12, #bold);
		if tarifa_vigente > 0 {
			draw "$" + round(tarifa_vigente * 100) / 100.0
			     at: location + {0, 80, 12}
			     color: #yellow font: font("Arial", 10, #bold);
		}
	}
}

// ── Estación Metro ────────────────────────────────────────────────────────────
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
		if pasajeros_espera > 0 {
			draw "" + pasajeros_espera at: location + {0, 80, 12}
			     color: (saturada ? #red : #limegreen) font: font("Arial", 9, #bold);
		}
	}
}

// ── GestorAMT — Agente BDI deliberativo (SMA.md §7.2) ────────────────────────
//
// Arquitectura BDI:
//   Creencias : densidad del polígono, velocidad media, tendencia de congestión,
//               estado de cada PuntoControl (tarifa actual, modo activo).
//   Deseos    : mantener la densidad vehicular del polígono por debajo del umbral
//               de congestión crítico, maximizar la recaudación y garantizar
//               que el modal shift al Metro no sature las estaciones.
//   Intenciones: MANTENER | SUBIR | BAJAR | SUSPENDER
//               Seleccionadas mediante deliberación cada 30 ciclos (5 min sim).
//
// FIX-2: el gestor escribe directamente sobre tarifa_vigente de cada PuntoControl
// mediante ask. El reflex cobrar del PuntoControl ya no interfiere en hora pico
// cuando GESTOR_ACTIVO = true.
// ─────────────────────────────────────────────────────────────────────────────
species GestorAMT {

	// ── Creencias ─────────────────────────────────────────────────────────────
	float densidad_poligono   <- 0.0;
	float velocidad_poligono  <- 0.0;
	int   tendencia            <- 0;
	float densidad_anterior    <- 0.0;
	float saturacion_metro     <- 0.0;
	string intencion_actual    <- "MANTENER";
	float tarifa_gestionada    <- 0.0;

	// ── Parámetros de deliberación ────────────────────────────────────────────
	float UMBRAL_DENSIDAD_ALTA <- 0.70;
	float UMBRAL_DENSIDAD_BAJA <- 0.40;
	float UMBRAL_VEL_CRITICA   <- 14.0;
	float UMBRAL_VEL_OPTIMA    <- 20.0;
	float UMBRAL_METRO_SAT     <- 0.85;
	float TARIFA_MIN_PICO      <- 0.50;
	float TARIFA_MAX           <- 3.00;
	float PASO_AJUSTE          <- 0.25;

	// ── Monitoreo de creencias (cada ciclo) ───────────────────────────────────
	reflex actualizar_creencias {
		densidad_anterior <- densidad_poligono;
		densidad_poligono <- length(ConductorBDI where (each.t_sin_avanzar = 0))
                     / float(max(1, length(ConductorBDI)));
		velocidad_poligono <- velocidad_media;
		float delta <- densidad_poligono - densidad_anterior;
		tendencia <- (delta > 0.03) ? 1 : ((delta < -0.03) ? -1 : 0);
		int espera_total    <- sum(EstacionMetro collect each.pasajeros_espera);
		int capacidad_total <- sum(EstacionMetro collect each.capacidad_hora);
		saturacion_metro    <- espera_total / float(max(1, capacidad_total));
	}

	// ── Deliberación BDI (cada 30 ciclos = 5 min simulados) ─────────────────
	// FIX-2: cuando delibera, inicializa siempre con tarifa_base del primer
	// PuntoControl activo para no partir de un valor desactualizado.
	reflex deliberar when: (cycle mod 30 = 0) and PEAJE_ACTIVO and GESTOR_ACTIVO
	                   and (dia_semana >= 1 and dia_semana <= 5) {

		string nueva_intencion <- "MANTENER";

		if (saturacion_metro >= UMBRAL_METRO_SAT and tendencia <= 0) {
			nueva_intencion <- "SUSPENDER";
		} else if (densidad_poligono >= UMBRAL_DENSIDAD_ALTA
		           and velocidad_poligono < UMBRAL_VEL_CRITICA
		           and saturacion_metro < UMBRAL_METRO_SAT) {
			nueva_intencion <- "SUBIR";
		} else if (tendencia = 1
		           and densidad_poligono > 0.55
		           and velocidad_poligono < UMBRAL_VEL_OPTIMA
		           and saturacion_metro < UMBRAL_METRO_SAT) {
			nueva_intencion <- "SUBIR";
		} else if (densidad_poligono <= UMBRAL_DENSIDAD_BAJA
		           and velocidad_poligono >= UMBRAL_VEL_OPTIMA) {
			nueva_intencion <- "BAJAR";
		} else if (tendencia = -1
		           and velocidad_poligono >= UMBRAL_VEL_OPTIMA) {
			nueva_intencion <- "BAJAR";
		}

		intencion_actual <- nueva_intencion;
		do ejecutar_intencion();
	}

	// ── Ejecución de la intención ─────────────────────────────────────────────
	action ejecutar_intencion {
		// Partir siempre de tarifa_base para no acumular ajustes indefinidamente
		list<PuntoControl> activos <- PuntoControl where each.modo_peaje_activo;
		float tarifa_actual <- empty(activos)
		    ? (es_hora_pico ? TARIFA_PICO_AUTO : 0.0)
		    : first(activos).tarifa_base;

		// Si el gestor ya había ajustado antes, continuar desde ese valor
		if tarifa_gestionada > 0.0 and es_hora_pico {
			tarifa_actual <- tarifa_gestionada;
		}

		float nueva_tarifa <- tarifa_actual;

		if intencion_actual = "SUBIR" {
			nueva_tarifa <- min(tarifa_actual + PASO_AJUSTE, TARIFA_MAX);
		} else if intencion_actual = "BAJAR" {
			float minimo <- es_hora_pico ? TARIFA_MIN_PICO : 0.0;
			nueva_tarifa <- max(tarifa_actual - PASO_AJUSTE, minimo);
		} else if intencion_actual = "SUSPENDER" {
			nueva_tarifa <- 0.0;
		}
		// MANTENER: nueva_tarifa = tarifa_actual (sin cambio)

		tarifa_gestionada <- nueva_tarifa;

		// Comunicar a todos los controles activos (patrón FIPA)
		ask PuntoControl where each.modo_peaje_activo {
			tarifa_vigente <- nueva_tarifa;
		}

		if intencion_actual != "MANTENER" {
			write "[GestorAMT] " + string(int(minuto_actual/60)) + "h"
			    + " | Intención: " + intencion_actual
			    + " | Densidad: " + round(densidad_poligono * 100) + "%"
			    + " | Vel: " + velocidad_poligono + " km/h"
			    + " | Tarifa: $" + tarifa_actual + " → $" + nueva_tarifa
			    + " | Metro sat: " + round(saturacion_metro * 100) + "%";
		}
	}

	aspect default {
		// El GestorAMT no se dibuja en el mapa; su estado está en el display dedicado.
	}
}

// ── Conductor BDI ─────────────────────────────────────────────────────────────
species ConductorBDI skills: [moving] {

	string nse               <- "MEDIO";
	float  wtp               <- 1.50;
	float  w_tiempo          <- 0.35;
	float  w_costo           <- 0.35;
	float  w_comodidad       <- 0.30;
	bool   restringido_placa <- false;
	bool   metro_accesible   <- false;
	float  tarifa_percibida  <- 0.0;
	string tipo_vehiculo       <- "AUTO";   // MOTO | AUTO | SUV | BUS | CARGA
    bool   exonerado_peaje     <- false;    // true → tarifa_efectiva = 0
    float  factor_capacidad_via <- 1.0;    // peso en road.nb_people
    float  tarifa_efectiva     <- 0.0;     // tarifa que realmente paga este agente
	float  speed             <- (rnd(5.0) + 3.0) * 10.0;
	float  nivel_congestion  <- 0.0;
	float  umbral_congestion <- 0.55;

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
		restringido_placa <- (rnd(1.0) < PCT_RESTRICCION_PLACA)
		                   and (dia_semana >= 1 and dia_semana <= 5);
		metro_accesible   <- rnd(1.0) < 0.60;
		pos_anterior      <- location;

    // ── NUEVO: propiedades específicas por tipo de vehículo ─────────────────
    if (tipo_vehiculo = "MOTO") {
        speed             <- speed + 40.0;   // mayor movilidad en tráfico denso
        factor_capacidad_via <- 0.3;          // menor huella en la vía
        exonerado_peaje   <- true;            // exonerada (propuesta DMQ)
        umbral_congestion <- max(0.20, umbral_congestion - 0.15); // más tolerante
        // NSE y WTP se mantienen para las decisiones de rerouting/metro

    } else if (tipo_vehiculo = "AUTO") {
        factor_capacidad_via <- 1.0;          // tipo base, sin cambio adicional

    } else if (tipo_vehiculo = "SUV") {
        speed             <- max(20.0, speed - 10.0); // más lento en tráfico
        factor_capacidad_via <- 1.5;          // mayor huella en la vía
        wtp               <- wtp * 1.3;       // mayor WTP (perfil más pudiente)

    } else if (tipo_vehiculo = "BUS") {
        speed             <- max(15.0, speed - 35.0); // velocidad bus urbano
        factor_capacidad_via <- 3.0;          // alto impacto en capacidad vial
        exonerado_peaje   <- true;            // exonerado siempre (SMA.md §7.2)
        metro_accesible   <- false;           // bus no puede "ir al Metro"
        restringido_placa <- false;           // buses no tienen restricción de placa
        nse               <- "BAJO";          // perfil de costo para contadores NSE

    } else if (tipo_vehiculo = "CARGA") {
        speed             <- max(10.0, speed - 40.0); // muy lento
        factor_capacidad_via <- 2.5;          // alto impacto en capacidad
        metro_accesible   <- false;           // carga no puede ir al Metro
        restringido_placa <- false;           // tiene restricción de zona, no de placa
        nse               <- "BAJO";
    }
	}

	reflex percibir {
		ask PuntoControl at_distance 300 {
			myself.tarifa_percibida <- self.tarifa_vigente;
		}
		if (exonerado_peaje) {
        // BUS y MOTO: siempre 0 independiente de la tarifa vigente
        tarifa_efectiva <- 0.0;
    } else if (tipo_vehiculo = "AUTO") {
        // Auto paga la tarifa vigente completa
        tarifa_efectiva <- tarifa_percibida;
    } else if (tipo_vehiculo = "SUV") {
        // SUV: tarifa proporcional (TARIFA_PICO_SUV / TARIFA_PICO_AUTO)
        float ratio <- (TARIFA_PICO_AUTO > 0.0) ? (TARIFA_PICO_SUV / TARIFA_PICO_AUTO) : 1.0;
        tarifa_efectiva <- tarifa_percibida * ratio;
    } else if (tipo_vehiculo = "CARGA") {
        // Carga: tarifa mayor (TARIFA_PICO_CARGA / TARIFA_PICO_AUTO)
        float ratio <- (TARIFA_PICO_AUTO > 0.0) ? (TARIFA_PICO_CARGA / TARIFA_PICO_AUTO) : 1.5;
        tarifa_efectiva <- tarifa_percibida * ratio;
    } else {
        tarifa_efectiva <- tarifa_percibida;
    }
		list<road> vias_cercanas <- road at_distance 200;
		if not empty(vias_cercanas) {
			int saturadas    <- length(vias_cercanas where (each.speed_coeff <= 0.5));
			nivel_congestion <- saturadas / float(length(vias_cercanas));
		} else {
			nivel_congestion <- 0.0;
		}
	}

	// FIX-4: trigger ampliado para garantizar deliberación en hora pico.
	// Condición adicional: si es hora pico, hay tarifa > 0 percibida y el agente
	// no decidió aún → deliberar cada 60 ciclos (10 min sim) aunque no haya
	// congestión suficiente. Esto cubre conductores en zonas poco congestionadas
	// que igual deben decidir ante el peaje activo.
	reflex deliberar when: not decision_tomada
                   and (
                       tarifa_efectiva > 0          // ← cambiado
                       or nivel_congestion >= umbral_congestion
                       or (es_hora_pico and PEAJE_ACTIVO and (cycle mod 60 = 0))
                   ) {
    do decidir();
}

	action decidir {
		// Prioridad 1: restricción de placa vigente
		if (tipo_vehiculo = "BUS") {
        intencion <- "RUTA_DIRECTA";
        count_ruta_directa <- count_ruta_directa + 1;
        chart_ruta_directa <- chart_ruta_directa + 1;
        // sin recaudacion (exonerado)
        count_directo_bajo <- count_directo_bajo + 1;  // NSE BAJO para buses
        decision_tomada <- true;
        return;
    }
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN) {
			count_restringidos <- count_restringidos + 1;
			chart_restringidos <- chart_restringidos + 1;
			intencion <- metro_accesible ? "METRO" : "REROUTEAR";
			if intencion = "METRO" {
				// FIX-1: guardar que hay estaciones antes de ask closest_to
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

		// Prioridad 2: función de utilidad multi-criterio
		float ud <- u_directa();
		float ur <- u_reroutear();
		float um <- u_metro();

		if (ud >= ur and ud >= um) {
			intencion          <- "RUTA_DIRECTA";
			count_ruta_directa <- count_ruta_directa + 1;
			chart_ruta_directa <- chart_ruta_directa + 1;
			recaudacion_acum <- recaudacion_acum + tarifa_efectiva;
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
			// FIX-1: verificar que existe al menos una EstacionMetro antes del ask
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
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN and intencion != "METRO") {
			if (cycle mod 300 = 0) {
				list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
				destino <- any_location_in(one_of(pool));
			}
			return;
		}
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
			list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
			destino          <- any_location_in(one_of(pool));
			decision_tomada  <- false;
			intencion        <- "RUTA_DIRECTA";
			tarifa_efectiva <- 0.0;
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
    // ── Color base por tipo de vehículo ──────────────────────────────────
    rgb col <- #gray;
    if      (tipo_vehiculo = "MOTO")  { col <- #deepskyblue; }
    else if (tipo_vehiculo = "AUTO")  { col <- #dodgerblue;  }
    else if (tipo_vehiculo = "SUV")   { col <- #mediumpurple;}
    else if (tipo_vehiculo = "BUS")   { col <- #limegreen;   }
    else if (tipo_vehiculo = "CARGA") { col <- #sienna;      }

    // ── Override por intención BDI ────────────────────────────────────────
    if (decision_tomada) {
        if      (intencion = "REROUTEAR") { col <- #orange; }
        else if (intencion = "METRO")     { col <- #gold;   }
    }

    // ── Override por restricción de placa vigente ─────────────────────────
    if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
        and minuto_actual <= RESTRICCION_FIN) { col <- #red; }

    // ── Tamaño diferenciado por tipo ──────────────────────────────────────
    float sz <- 8.0;
	if      (tipo_vehiculo = "MOTO")  { sz <- 5.0;  }
	else if (tipo_vehiculo = "SUV")   { sz <- 10.0; }
	else if (tipo_vehiculo = "BUS")   { sz <- 14.0; }
	else if (tipo_vehiculo = "CARGA") { sz <- 12.0; }
	
	draw circle(sz) at: location + {0, 0, 5} color: col border: #black;
}
}

// ── Experimento EB ─────────────────────────────────────────────────────────────
experiment "EB — Peaje Franja Horaria" type: gui autorun: true {

	parameter "Motos (~15 %)"              var: NB_MOTOS   min: 0  max: 150 step: 15  category: "Vehículos";
	parameter "Autos particulares (~55 %)" var: NB_AUTOS   min: 0  max: 300 step: 25  category: "Vehículos";
	parameter "SUV / 4x4 (~15 %)"         var: NB_SUVS    min: 0  max: 150 step: 15  category: "Vehículos";
	parameter "Buses / T. público (~10 %)" var: NB_BUSES   min: 0  max: 100 step: 10  category: "Vehículos";
	parameter "Vehículos de carga (~5 %)"  var: NB_CARGAS  min: 0  max: 50  step: 5   category: "Vehículos";
	
	parameter "Día semana (1=Lun,7=Dom)"   var: dia_semana min: 1  max: 7             category: "Sim";
	
	parameter "Tarifa AUTO pico (USD)"     var: TARIFA_PICO_AUTO  min: 0.5 max: 3.0 step: 0.25 category: "Peaje";
	parameter "Tarifa MOTO pico (USD)"     var: TARIFA_PICO_MOTO  min: 0.0 max: 2.0 step: 0.25 category: "Peaje";
	parameter "Tarifa SUV pico (USD)"      var: TARIFA_PICO_SUV   min: 0.5 max: 4.0 step: 0.25 category: "Peaje";
	parameter "Tarifa CARGA pico (USD)"    var: TARIFA_PICO_CARGA min: 0.0 max: 5.0 step: 0.50 category: "Peaje";
	parameter "Peaje activo"               var: PEAJE_ACTIVO                                    category: "Peaje";
	parameter "Gestor AMT activo"          var: GESTOR_ACTIVO                                       category: "Peaje";

	float minimum_cycle_duration <- 0.01;

	output synchronized: true {

		// ── Mapa principal ────────────────────────────────────────────────────
		display "Mapa La Carolina — EB" type: 3d axes: false
		        background: rgb(25, 25, 25) toolbar: false {
			overlay position: {50 #px, 50 #px} size: {1 #px, 1 #px}
			        background: #black border: #black rounded: false {
				draw "SMA — La Carolina  [EB]" at: {0, 0} anchor: #top_left
				     color: #orange font: font("Arial", 16, #bold);
				int hh <- int(minuto_actual / 60);
				int mm_ <- minuto_actual mod 60;
				draw "Hora: " + hh + ":" + (mm_ < 10 ? "0" : "") + mm_
				     + (es_hora_pico ? "  ◀ PICO" : "")
				     at: {0, 40 #px} anchor: #top_left
				     color: (es_hora_pico ? #orange : #white)
				     font: font("Arial", 12, #bold);
				draw "Vel: " + velocidad_media + " km/h"
				     at: {0, 70 #px} anchor: #top_left
				     color: #white font: font("Arial", 12, #bold);
				float t_actual <- empty(PuntoControl) ? 0.0
				    : first(PuntoControl).tarifa_vigente;
				draw "Tarifa: $" + round(t_actual * 100) / 100.0 + " USD"
				     at: {0, 95 #px} anchor: #top_left
				     color: (t_actual > 0 ? #red : #limegreen)
				     font: font("Arial", 12, #bold);
				draw "Recaudado: $" + round(recaudacion_acum * 100) / 100.0
				     at: {0, 120 #px} anchor: #top_left
				     color: #gold font: font("Arial", 11, #bold);

				float y <- 160 #px;
				loop item over: [
    ["Moto",          #deepskyblue],
    ["Auto",          #dodgerblue],
    ["SUV / 4x4",     #mediumpurple],
    ["Bus",           #limegreen],
    ["Carga",         #sienna],
    ["Restringido",   #red]
] {
    draw circle(10 #px) at: {14 #px, y} color: rgb(rgb(item[1]), 0.90);
    draw string(item[0]) at: {34 #px, y} anchor: #left_center
         color: #white font: font("Arial", 10, #bold);
    y <- y + 28 #px;
}

y <- y + 10 #px;
draw "— Decisión BDI —" at: {14 #px, y} anchor: #left_center
     color: rgb(180, 180, 180) font: font("Arial", 9, #plain);
y <- y + 22 #px;

loop item over: [
    ["Reroutan",  #orange],
    ["→ Metro",   #gold]
] {
    draw square(18 #px) at: {14 #px, y} color: rgb(rgb(item[1]), 0.85);
    draw string(item[0]) at: {34 #px, y} anchor: #left_center
         color: #white font: font("Arial", 10, #bold);
    y <- y + 28 #px;
}
				
			}
			light #ambient intensity: 130;
			species road         refresh: false;
			species PuntoControl;
			species EstacionMetro;
			species ConductorBDI;
		}

		// ── Flujo vehicular ───────────────────────────────────────────────────
		display "Flujo vehicular — EB" {
			chart "Conductores en la red" type: series
			      background: rgb(25, 25, 25) color: #white {
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

		// ── Decisiones BDI ────────────────────────────────────────────────────
		display "Decisiones BDI — EB" {
			chart "Distribución de decisiones" type: pie
			      background: rgb(25, 25, 25) color: #white {
				data "Ruta directa" value: chart_ruta_directa color: #dodgerblue;
				data "Reroutan"     value: chart_reroutean     color: #orange;
				data "→ Metro"      value: chart_metro         color: #limegreen;
				data "Restringidos" value: chart_restringidos  color: #red;
			}
		}

		// ── Velocidad y tarifa ────────────────────────────────────────────────
		display "Velocidad y Tarifa — EB" {
			chart "Velocidad media (km/h) y Tarifa vigente (USD)"
			      type: series background: rgb(25, 25, 25) color: #white {
				data "Velocidad (km/h)" value: velocidad_media  color: #limegreen;
				// Tarifa ×10 para visualización conjunta en el mismo eje
				data "Tarifa × 10 (USD)"
				     value: (empty(PuntoControl) ? 0.0
				             : first(PuntoControl).tarifa_vigente * 10.0)
				     color: #orange;
			}
		}

		// ── Recaudación acumulada ─────────────────────────────────────────────
		display "Recaudación — EB" {
			chart "Recaudación acumulada (USD)" type: series
			      background: rgb(25, 25, 25) color: #white {
				data "USD acumulados" value: recaudacion_acum color: #gold;
			}
		}

		// ── Equidad NSE ───────────────────────────────────────────────────────
		display "Equidad NSE — EB" {
			chart "Decisiones por NSE (acumulado)" type: histogram
			      background: rgb(25, 25, 25) color: #white {
				data "Directo ALTO"   value: count_directo_alto  color: rgb(30, 144, 255);
				data "Directo MEDIO"  value: count_directo_medio color: rgb(100, 180, 255);
				data "Directo BAJO"   value: count_directo_bajo  color: rgb(180, 220, 255);
				data "Metro ALTO"     value: count_metro_alto    color: rgb(50, 200, 50);
				data "Metro MEDIO"    value: count_metro_medio   color: rgb(100, 220, 100);
				data "Metro BAJO"     value: count_metro_bajo    color: rgb(180, 240, 180);
				data "Rerouta ALTO"   value: count_rerouta_alto  color: rgb(255, 140, 0);
				data "Rerouta MEDIO"  value: count_rerouta_medio color: rgb(255, 180, 60);
				data "Rerouta BAJO"   value: count_rerouta_bajo  color: rgb(255, 220, 140);
			}
		}

		// ── GestorAMT — Panel de monitoreo BDI ───────────────────────────────
		display "GestorAMT — Estado BDI" {
			chart "Creencias del GestorAMT" type: series
			      background: rgb(25, 25, 25) color: #white {
				data "Densidad % × 100"
				     value: (empty(GestorAMT) ? 0.0
				             : first(GestorAMT).densidad_poligono * 100.0)
				     color: #orange;
				data "Velocidad (km/h)"
				     value: velocidad_media
				     color: #limegreen;
				data "Tarifa × 10 (USD)"
				     value: (empty(GestorAMT) ? 0.0
				             : first(GestorAMT).tarifa_gestionada * 10.0)
				     color: #red;
				data "Sat. Metro % × 100"
				     value: (empty(GestorAMT) ? 0.0
				             : first(GestorAMT).saturacion_metro * 100.0)
				     color: #royalblue;
			}
		}
	}
}
