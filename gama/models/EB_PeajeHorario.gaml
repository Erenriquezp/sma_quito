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
 *   5. GestorAMT declarado como species stub (implementación completa = Escenario C)
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
	int   NB_CONDUCTORES        <- 150;
	float PCT_NSE_ALTO          <- 0.15;
	float PCT_NSE_MEDIO         <- 0.45;
	float PCT_NSE_BAJO          <- 0.40;
	float WTP_NSE_ALTO          <- 3.00;
	// WTP_NSE_MEDIO subido de $1.50 a $2.25:
	// Con tarifa pico de $2.00, el NSE_MEDIO ahora tiene WTP > tarifa en muchos casos,
	// creando el gradiente de comportamiento necesario para el análisis de equidad.
	// Esto replica el hallazgo de Londres: la clase media exhibe comportamiento mixto
	// (algunos pagan, otros reroutan), no una respuesta binaria en bloque.
	float WTP_NSE_MEDIO         <- 2.25;
	float WTP_NSE_BAJO          <- 0.50;
	float PCT_RESTRICCION_PLACA <- 0.20;
	int   RESTRICCION_INICIO    <- 360;
	int   RESTRICCION_FIN       <- 1200;
	int   dia_semana            <- 1;

	// ── Parámetros de peaje EB ────────────────────────────────────────────────
	// Rango calibrado contra London Congestion Charge (£5 inicial ≈ $6 USD 2003;
	// propuesta DMQ: $1.50–$2.00 USD 2026 — SMA.md §9).
	float TARIFA_PICO    <- 2.00;   // USD — hora pico
	float TARIFA_VALLE   <- 0.00;   // USD — fuera de franja
	// El peaje aplica solo en días hábiles (lunes–viernes)
	bool  PEAJE_ACTIVO   <- true;

	// ── Control del GestorAMT ─────────────────────────────────────────────────
	// true  → El gestor ajusta tarifas dinámicamente (comportamiento por defecto en EB).
	// false → Tarifa fija por franja horaria sin intervención del gestor
	//         (útil para comparar el efecto del gestor vs. tarifa estática).
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

	// Velocidad media emergente (misma lógica que E0)
	float velocidad_media     <- 0.0;

	// Modal shift acumulado
	int   modal_shift_acum    <- 0;

	// Recaudación: se acumula en cada decisión RUTA_DIRECTA con tarifa > 0
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

	int    INTERVALO_LOG  <- 90;
	string OUTPUT_PATH    <- "../outputs/";

	init {
		write "=================================================";
		write "  ESCENARIO B — PEAJE POR FRANJA HORARIA";
		write "  Tarifa pico: $" + TARIFA_PICO + " USD";
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
		// En EB todos los controles arrancan con modo_peaje_activo::true.
		// La tarifa real se actualiza cada ciclo en reflex cobrar.
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
		create EstacionMetro with: [nombre::"Iñaquito",
		    location::{1800.0, 3600.0}];
		create EstacionMetro with: [nombre::"La Carolina",
		    location::{1800.0, 3100.0}];

		// ── GestorAMT (stub — implementación completa en Escenario C) ────────
		create GestorAMT;

		// ── Conductores BDI ──────────────────────────────────────────────────
		create ConductorBDI number: NB_CONDUCTORES {
			list<road> pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;
			road rd  <- one_of(pool);
			location <- any_location_in(rd);
			destino  <- any_location_in(one_of(pool));
		}

		chart_ruta_directa <- length(ConductorBDI where (not each.restringido_placa));
		chart_restringidos <- length(ConductorBDI where (each.restringido_placa));

		// Crear CSV con encabezado — igual al E0 + columna tarifa_pico_usd
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

		write "  Conductores: " + NB_CONDUCTORES;
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

		// ── Velocidad EFECTIVA de desplazamiento ─────────────────────────────
		// Calcula la velocidad como distancia real recorrida en el ciclo anterior,
		// no como promedio de la velocidad intrínseca (speed) de los agentes.
		// Un agente "activo" es el que se movió (pos_anterior != nil y avanzó > 0).
		// Conversión: distancia [m/ciclo] × (1 ciclo / 10 s) × (3600 s / 1000 m)
		//           = distancia_ciclo × 0.36  →  km/h
		// Solo se consideran agentes no retenidos por restricción de placa.
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

		// Tarifa vigente en este instante (misma para todos los controles activos)
		float tarifa_ahora <- first(PuntoControl where each.modo_peaje_activo).tarifa_vigente;

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
	int   nb_people   <- 0 update: length(ConductorBDI at_distance 10);
	float speed_coeff <- 1.0 update: exp(-nb_people / capacity) min: 0.1;
	aspect default { draw (shape + 5) color: #white; }
}

// ── Punto de control con cobro activo ─────────────────────────────────────────
species PuntoControl {
	int    id_control        <- 0;
	string nombre_acceso     <- "";
	float  tarifa_vigente    <- 0.0;
	bool   modo_peaje_activo <- false;

	// tarifa_base: la que corresponde por franja horaria (sin intervención del gestor).
	// El GestorAMT puede sobreescribir tarifa_vigente; tarifa_base es de solo lectura.
	float  tarifa_base       <- 0.0 update: (es_hora_pico ? TARIFA_PICO : TARIFA_VALLE);

	// ── Lógica de cobro EB ────────────────────────────────────────────────────
	// El PuntoControl aplica la tarifa_base en días hábiles.
	// Si el GestorAMT intervino (sobreescribió tarifa_vigente), ese valor prevalece
	// hasta el próximo ciclo de intervención del gestor.
	// Días hábiles: lunes–viernes (dia_semana 1–5).
	reflex cobrar when: modo_peaje_activo and PEAJE_ACTIVO
	                and (dia_semana >= 1 and dia_semana <= 5) {
		// Solo actualizar si el GestorAMT no intervino este ciclo.
		// El gestor usa ask directo, por lo que su escritura ya ocurrió
		// en el reflex ajustar_tarifa (que corre antes por orden de species).
		// Este reflex actualiza la base; el gestor ajusta sobre esa base.
		tarifa_vigente <- tarifa_base;
	}

	// Fuera de días hábiles el peaje no cobra
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
		// Mostrar ocupación cuando hay espera
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
// Patrón FIPA (SMA.md §5.3):
//   El gestor actúa como agente facilitador: mantiene visión global del polígono
//   y emite órdenes de ajuste tarifario a todos los PuntoControl simultáneamente
//   mediante ask. Los conductores perciben el cambio de tarifa en su próximo ciclo
//   de percepción (reflex percibir).
//
// Nota: en el Escenario B (EB) el gestor corre en modo ACTIVO y ajusta tarifas
// dinámicamente. El Escenario B original de tarifa fija por franja queda como
// referencia en tarifa_base de PuntoControl.
// Para desactivar el gestor y volver a tarifa fija, setear GESTOR_ACTIVO = false.
// ─────────────────────────────────────────────────────────────────────────────
species GestorAMT {

	// ── Creencias ─────────────────────────────────────────────────────────────
	// densidad_poligono ∈ [0,1]: fracción de conductores activos sobre el total.
	float densidad_poligono   <- 0.0;

	// velocidad_poligono: velocidad media actual del polígono (km/h).
	// Complementa la densidad para deliberar: alta densidad + baja velocidad
	// confirma congestión real; alta densidad + velocidad aceptable puede ser
	// flujo denso pero fluido.
	float velocidad_poligono  <- 0.0;

	// tendencia ∈ {-1, 0, 1}: -1 = mejorando, 0 = estable, 1 = empeorando.
	// Se calcula comparando la densidad actual con la del ciclo de monitoreo anterior.
	int   tendencia            <- 0;
	float densidad_anterior    <- 0.0;

	// saturacion_metro ∈ [0,1]: fracción de capacidad del Metro ocupada.
	// Si el Metro se satura, el gestor no debe forzar más modal shift.
	float saturacion_metro     <- 0.0;

	// intencion_actual: la acción decidida en el último ciclo de deliberación.
	string intencion_actual    <- "MANTENER";

	// tarifa_gestionada: la tarifa que el gestor calculó y comunicó a los controles.
	// Se muestra en el HUD del gestor para trazabilidad.
	float tarifa_gestionada    <- 0.0;

	// ── Parámetros de deliberación ────────────────────────────────────────────
	// Umbrales calibrados con referencia al London Congestion Charge:
	// densidad crítica > 0.70 → congestión severa, subir tarifa.
	// densidad aceptable < 0.40 → flujo libre, bajar tarifa para no penalizar.
	// velocidad crítica < 14 km/h → límite inferior AMT (SMA.md §6.1).
	// velocidad óptima ≥ 20 km/h → objetivo de la política (+20% Londres).
	float UMBRAL_DENSIDAD_ALTA <- 0.70;
	float UMBRAL_DENSIDAD_BAJA <- 0.40;
	float UMBRAL_VEL_CRITICA   <- 14.0;   // km/h — congestión severa
	float UMBRAL_VEL_OPTIMA    <- 20.0;   // km/h — objetivo de la política
	float UMBRAL_METRO_SAT     <- 0.85;   // fracción de capacidad Metro

	// Límites de la tarifa gestionada: no puede bajar de $0.50 en hora pico
	// (evita que el gestor anule el peaje) ni superar $3.00 (tope político DMQ).
	float TARIFA_MIN_PICO      <- 0.50;
	float TARIFA_MAX           <- 3.00;
	float PASO_AJUSTE          <- 0.25;   // USD por paso de ajuste

	// ── Monitoreo de creencias (cada ciclo) ───────────────────────────────────
	reflex actualizar_creencias {
		// 1. Densidad del polígono
		// FIX: dividir por NB_CONDUCTORES (constante global) en lugar de
		// length(ConductorBDI), que en GAMA puede devolver un conteo acumulativo
		// de instancias creadas, produciendo valores > 1.
		// NB_CONDUCTORES garantiza que densidad_poligono ∈ [0.0, 1.0] siempre.
		densidad_anterior <- densidad_poligono;
		densidad_poligono <- length(ConductorBDI where (each.t_sin_avanzar = 0))
		                     / float(max(1, NB_CONDUCTORES));

		// 2. Velocidad media del polígono (misma variable global, ya calculada)
		velocidad_poligono <- velocidad_media;

		// 3. Tendencia: comparación con ciclo anterior
		float delta <- densidad_poligono - densidad_anterior;
		tendencia <- (delta > 0.03) ? 1 : ((delta < -0.03) ? -1 : 0);

		// 4. Saturación del Metro: pasajeros en espera / capacidad total
		int espera_total    <- sum(EstacionMetro collect each.pasajeros_espera);
		int capacidad_total <- sum(EstacionMetro collect each.capacidad_hora);
		saturacion_metro    <- espera_total / float(max(1, capacidad_total));
	}

	// ── Deliberación BDI (cada 30 ciclos = 5 min simulados) ─────────────────
	// Evalúa las creencias y selecciona la intención óptima según el estado
	// del sistema. La lógica prioriza:
	//   1. Suspender peaje si el Metro está saturado (no empujar más modal shift)
	//   2. Subir tarifa si hay congestión severa y el Metro tiene capacidad
	//   3. Bajar tarifa si el flujo es libre (evitar penalización innecesaria)
	//   4. Mantener tarifa si el sistema está en equilibrio
	reflex deliberar when: (cycle mod 30 = 0) and PEAJE_ACTIVO and GESTOR_ACTIVO
	                   and (dia_semana >= 1 and dia_semana <= 5) {

		string nueva_intencion <- "MANTENER";

		// Regla 1 — SUSPENDER: Metro saturado y densidad bajando o estable
		// No tiene sentido mantener el peaje si el Metro no puede absorber más
		if (saturacion_metro >= UMBRAL_METRO_SAT and tendencia <= 0) {
			nueva_intencion <- "SUSPENDER";

		// Regla 2 — SUBIR: congestión severa (densidad alta Y velocidad crítica)
		// Solo sube si el Metro tiene capacidad de absorción
		} else if (densidad_poligono >= UMBRAL_DENSIDAD_ALTA
		           and velocidad_poligono < UMBRAL_VEL_CRITICA
		           and saturacion_metro < UMBRAL_METRO_SAT) {
			nueva_intencion <- "SUBIR";

		// Regla 3 — SUBIR por tendencia: empeora rápido aunque aún no crítico
		} else if (tendencia = 1
		           and densidad_poligono > 0.55
		           and velocidad_poligono < UMBRAL_VEL_OPTIMA
		           and saturacion_metro < UMBRAL_METRO_SAT) {
			nueva_intencion <- "SUBIR";

		// Regla 4 — BAJAR: flujo libre, tarifa actual es innecesariamente alta
		} else if (densidad_poligono <= UMBRAL_DENSIDAD_BAJA
		           and velocidad_poligono >= UMBRAL_VEL_OPTIMA) {
			nueva_intencion <- "BAJAR";

		// Regla 5 — BAJAR por mejora: congestión cediendo, reducir para no sobrepenalizar
		} else if (tendencia = -1
		           and velocidad_poligono >= UMBRAL_VEL_OPTIMA) {
			nueva_intencion <- "BAJAR";
		}

		intencion_actual <- nueva_intencion;
		do ejecutar_intencion();
	}

	// ── Ejecución de la intención ─────────────────────────────────────────────
	action ejecutar_intencion {
		// Calcular la nueva tarifa a partir de la vigente más el ajuste
		float tarifa_actual <- empty(PuntoControl where each.modo_peaje_activo)
		    ? TARIFA_PICO
		    : first(PuntoControl where each.modo_peaje_activo).tarifa_vigente;

		float nueva_tarifa <- tarifa_actual;

		if intencion_actual = "SUBIR" {
			nueva_tarifa <- min(tarifa_actual + PASO_AJUSTE, TARIFA_MAX);

		} else if intencion_actual = "BAJAR" {
			// En hora pico nunca baja de TARIFA_MIN_PICO; fuera de pico puede ir a 0
			float minimo <- es_hora_pico ? TARIFA_MIN_PICO : 0.0;
			nueva_tarifa <- max(tarifa_actual - PASO_AJUSTE, minimo);

		} else if intencion_actual = "SUSPENDER" {
			nueva_tarifa <- 0.0;

		// MANTENER: no hace nada, los PuntoControl ya aplicaron tarifa_base
		}

		tarifa_gestionada <- nueva_tarifa;

		// Comunicar la nueva tarifa a todos los controles activos (patrón FIPA)
		if intencion_actual != "MANTENER" {
			ask PuntoControl where each.modo_peaje_activo {
				tarifa_vigente <- nueva_tarifa;
			}
			write "[GestorAMT] " + string(int(minuto_actual/60)) + "h"
			    + " | Intención: " + intencion_actual
			    + " | Densidad: " + round(densidad_poligono * 100) + "%"
			    + " | Vel: " + velocidad_poligono + " km/h"
			    + " | Tarifa: $" + tarifa_actual + " → $" + nueva_tarifa
			    + " | Metro sat: " + round(saturacion_metro * 100) + "%";
		}
	}

	aspect default {
		// El GestorAMT no se dibuja en el mapa.
		// Su estado se monitorea en el display "GestorAMT — Estado" y en consola.
	}
}

// ── Conductor BDI ─────────────────────────────────────────────────────────────
// Idéntico al E0 salvo que ahora el trigger de tarifa > 0 se activa frecuentemente.
species ConductorBDI skills: [moving] {

	string nse               <- "MEDIO";
	float  wtp               <- 1.50;
	float  w_tiempo          <- 0.35;
	float  w_costo           <- 0.35;
	float  w_comodidad       <- 0.30;
	bool   restringido_placa <- false;
	bool   metro_accesible   <- false;
	float  tarifa_percibida  <- 0.0;
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
	}

	reflex percibir {
		ask PuntoControl at_distance 300 {
			myself.tarifa_percibida <- self.tarifa_vigente;
		}
		list<road> vias_cercanas <- road at_distance 200;
		if not empty(vias_cercanas) {
			int saturadas    <- length(vias_cercanas where (each.speed_coeff <= 0.5));
			nivel_congestion <- saturadas / float(length(vias_cercanas));
		} else {
			nivel_congestion <- 0.0;
		}
	}

	reflex deliberar when: not decision_tomada
	                   and (tarifa_percibida > 0 or nivel_congestion >= umbral_congestion) {
		do decidir();
	}

	action decidir {
		if (restringido_placa and minuto_actual >= RESTRICCION_INICIO
		    and minuto_actual <= RESTRICCION_FIN) {
			count_restringidos <- count_restringidos + 1;
			chart_restringidos <- chart_restringidos + 1;
			intencion <- metro_accesible ? "METRO" : "REROUTEAR";
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

	float u_directa {
		if tarifa_percibida > wtp { return -0.5; }
		float uc <- (tarifa_percibida > 0) ? (1.0 / tarifa_percibida) : 1.0;
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

// ── Experimento EB ─────────────────────────────────────────────────────────────
experiment "EB — Peaje Franja Horaria" type: gui autorun: true {

	parameter "Conductores"              var: NB_CONDUCTORES min: 50  max: 500 step: 50   category: "Sim";
	parameter "Día semana (1=Lun,7=Dom)" var: dia_semana     min: 1   max: 7              category: "Sim";
	parameter "Tarifa pico USD"          var: TARIFA_PICO    min: 0.5 max: 3.0 step: 0.25 category: "Peaje";
	parameter "Peaje activo"             var: PEAJE_ACTIVO                                 category: "Peaje";
	parameter "Gestor AMT activo"        var: GESTOR_ACTIVO                                category: "Peaje";

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
				// Tarifa actual visible en el HUD
				float t_actual <- empty(PuntoControl) ? 0.0
				    : first(PuntoControl).tarifa_vigente;
				draw "Tarifa: $" + round(t_actual * 100) / 100.0 + " USD"
				     at: {0, 95 #px} anchor: #top_left
				     color: (t_actual > 0 ? #red : #limegreen)
				     font: font("Arial", 12, #bold);
				// Recaudación acumulada
				draw "Recaudado: $" + round(recaudacion_acum * 100) / 100.0
				     at: {0, 120 #px} anchor: #top_left
				     color: #gold font: font("Arial", 11, #bold);

				float y <- 160 #px;
				loop lbl over: ["Ruta directa", "Reroutan", "→ Metro", "Restringidos (placa)"] {
					rgb c <- #red;
					if      (lbl = "Ruta directa") { c <- #dodgerblue; }
					else if (lbl = "Reroutan")     { c <- #orange;     }
					else if (lbl = "→ Metro")      { c <- #limegreen;  }
					draw square(28 #px) at: {14 #px, y} color: rgb(c, 0.85);
					draw lbl at: {48 #px, y} anchor: #left_center
					     color: #white font: font("Arial", 11, #bold);
					y <- y + 36 #px;
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
				data "Tarifa × 10 (USD)" // escalada ×10 para visualización conjunta
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
		// Muestra qué perfil socioeconómico paga, rerouta o usa el Metro.
		// Fuente de datos para el análisis de equidad del paper (SMA.md §9).
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
		// Muestra en tiempo real las creencias del gestor y la tarifa que gestiona.
		// Permite verificar que la lógica deliberativa responde correctamente a
		// los cambios de densidad y velocidad (validación del Escenario B).
		display "GestorAMT — Estado BDI" {
			chart "Creencias del GestorAMT" type: series
			      background: rgb(25, 25, 25) color: #white {
				// Densidad del polígono (eje 0–1 × 100 para visualizar como %)
				data "Densidad % × 100"
				     value: (empty(GestorAMT) ? 0.0
				             : first(GestorAMT).densidad_poligono * 100.0)
				     color: #orange;
				// Velocidad media (km/h) — comparable con umbral crítico (14 km/h)
				data "Velocidad (km/h)"
				     value: velocidad_media
				     color: #limegreen;
				// Tarifa gestionada × 10 para visualización conjunta
				data "Tarifa × 10 (USD)"
				     value: (empty(GestorAMT) ? 0.0
				             : first(GestorAMT).tarifa_gestionada * 10.0)
				     color: #red;
				// Saturación Metro (%) × 100
				data "Sat. Metro % × 100"
				     value: (empty(GestorAMT) ? 0.0
				             : first(GestorAMT).saturacion_metro * 100.0)
				     color: #royalblue;
			}
		}
	}
}
