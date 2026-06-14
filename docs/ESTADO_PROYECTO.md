# Estado del Proyecto — SMA Movilidad Urbana Quito

> **Última revisión:** 13 de junio de 2026
> **Qué es esto:** una foto del proyecto frente a su objetivo y alcance — qué está
> listo, qué falta y qué queda por corregir. No es un registro de cambios; para el
> detalle histórico ver `INFORME_CAMBIOS_V2.md` y el historial de commits.

---

## Objetivo y alcance (según `docs/SMA.md`)

**Objetivo.** SMA con arquitectura BDI y datos geoespaciales reales que simule y evalúe
una **zona de cobro por congestión en el Parque La Carolina (Quito)**, comparando un
baseline sin peaje contra un peaje por franja horaria, y documente los resultados en un
paper académico (IEEE).

**Hipótesis a contrastar (§2.3).** El peaje reduce el volumen vehicular de paso **≥ 20 %**,
incrementa el uso del Metro y no genera desplazamiento periférico crítico, tomando como
referencia el −27 % del *London Congestion Charge* (2003).

**Alcance acordado (§8).** Dos escenarios al mismo horizonte (06:00–22:00):
- **E0 — Baseline:** pico y placa activo, sin cobro, Metro disponible.
- **EB — Peaje por franja horaria:** $0 fuera de pico; $1.50–$2.00 en pico (07–10 h y
  17–20 h), modelo Londres, con tercera placa.
- Escenarios A (peaje fijo 24 h) y C (tarifa dinámica pura) quedan como trabajo futuro.

Seis tipos de agente (§7.2): Conductor BDI, Punto de control, Estación Metro, Gestor AMT,
Red vial y Transporte público exonerado.

---

## Resumen en una línea

La **arquitectura, el modelo y el pipeline están completos y funcionando**; lo único que
bloquea los resultados del paper es **correr ambos escenarios completos (06:00–22:00)** —
hoy solo existen corridas parciales de la mañana.

---

## 1. Lo que está listo ✅

### Modelos GAML (`gama/models/`)
- **Infraestructura:** carga del shapefile real (`red_vial_la_carolina.shp`, EPSG:32717),
  componente conexo, reloj 06:00–22:00 (`step 10 #s`), detección de hora pico, export CSV
  cada ~15 min sim con header protegido.
- **`ConductorBDI`:** perfil NSE (15/45/40 %) con WTP, pesos de utilidad y umbral de
  congestión por nivel; tres intenciones (RUTA_DIRECTA / REROUTEAR / METRO) por utilidad
  multicriterio; **diferenciación por tipo de vehículo** (moto/auto/SUV/bus/carga) con
  velocidad, ocupación de vía y exoneración; **tercera placa en ambos escenarios**.
- **`PuntoControl`:** 5 accesos C1–C5; tarifa por franja en EB; convivencia con el gestor
  (el gestor escribe `tarifa_vigente` en pico); cobro $0 fines de semana.
- **`GestorAMT` (EB):** BDI deliberativo (creencias densidad/velocidad/tendencia/saturación
  → MANTENER/SUBIR/BAJAR/SUSPENDER cada 30 ciclos) con comunicación FIPA a los puntos de
  control y display dedicado.
- **`EstacionMetro`:** 2 estaciones (Iñaquito, La Carolina), atractor de modal shift.
- **Velocidad media** estimada por coeficiente de congestión dentro del polígono; el cambio
  modal al Metro descongestiona la vía.

### Datos geoespaciales y visualización
- Coordenadas reales (UTM 17S) de C1–C5, estaciones y polígono de cobro, convertidas en
  runtime con `to_GAMA_CRS(..., "EPSG:32717")` para calzar con la red (GAMA normaliza el
  shapefile al cargarlo). *Pendiente de verificación visual — ver §3.*
- Displays depurados: se quitaron las gráficas casi lineales (velocidad, recaudación,
  reparto modal en el tiempo) que se analizarán mejor desde Python. Quedan el **mapa**
  (polígono dibujado, compuertas como frontera, conductores diferenciados dentro/fuera,
  HUD con jerarquía clara), el **pastel de decisiones BDI** y, en EB, **equidad NSE** y el
  **estado del GestorAMT**.

### Pipeline Python (`analysis/scripts/`)
- Corre `01→02→03` de punta a punta sobre datos reales (sin caer en sintéticos).
- Etiqueta unificada `E0_HET`; columnas de flujo derivadas de los contadores NSE reales;
  corrección de equidad por buses (`*_corr`); UTF-8 y `to_latex` con fallback en Windows.
- Produce `combined.csv`, tablas comparativas, tabla benchmark y 5 figuras (PNG + PDF).

---

## 2. Lo que falta ❌

### 🔴 Bloqueante único — datos completos
**Correr E0_HET y EB completos (06:00–22:00, hasta `do pause`) al mismo horizonte.** Hoy
las corridas son parciales (E0 llega a ~06:45 = 3 filas; EB a ~07:15 = 5 filas). Esto es lo
único que falta para:
- estabilizar el % de reducción vehicular (osciló −18…−27 % en parciales),
- incluir el **pico vespertino** (17–20 h), hoy ausente,
- dar potencia a los t-tests (no significativos por n pequeño).

Tras la corrida, regenerar `analysis/results/` y las figuras.

### 🟡 Análisis y paper
- **Figura de equidad NSE (Δ Gini modal)** e implementación del cálculo con columnas `*_corr`.
- **Figura de recaudación y tarifa dinámica** del GestorAMT (datos disponibles en EB).
- **Plantilla LaTeX Overleaf (IEEE)** con las 6 secciones de `SMA.md §15`; la Metodología
  ya es redactable desde el código.
- Sección **Discusión** con el benchmark Londres.

### 🟢 Entregables y calidad
- **CSV de parámetros BDI** por perfil NSE y **tabla de calibración AMT** (entregables P2;
  hoy los parámetros están hardcoded).
- **Polígono de cobro como capa de área GIS** para el paper (hoy se dibuja en GAMA pero no
  existe como capa).

### 🟣 Nuevo requerimiento — modelo configurable de zona/mapa
Crear un **tercer modelo** que permita **cambiar de zona** (cargar otro mapa y ajustar las
zonas de cobro) manteniendo el mismo comportamiento del SMA. Requisitos:
- **No tocar los modelos actuales:** partir de una **copia** de `EB_PeajeHorario.gaml`
  (el más completo) hacia un nuevo archivo (p. ej. `gama/models/ZonaConfigurable.gaml`),
  para no corromper E0 ni EB que ya funcionan.
- **Mapa intercambiable:** la red vial debe ser un parámetro (ruta del shapefile y
  `CRS_DATOS`), no un valor fijo, para apuntar a otra zona sin editar el código.
- **Zonas de cobro ajustables:** el polígono de cobro y las posiciones de los puntos de
  control / estaciones deben ser configurables (parámetros o un archivo de definición de
  zona), no constantes embebidas en el `init`.
- **Mismo funcionamiento:** conductores BDI, gestor AMT, métricas y export CSV deben operar
  igual que en EB, sin depender de geometrías específicas de La Carolina.

> *Consideración de diseño:* hoy la geometría está hardcoded en el `init` de cada modelo
> (coordenadas UTM + `to_GAMA_CRS`). Para que el tercer modelo sea realmente reutilizable
> conviene externalizar la zona a parámetros del experimento o a un shapefile/CSV de zona,
> en vez de copiar y reescribir coordenadas a mano por cada nueva área.

---

## 3. Correcciones pendientes 🔧

| # | Tema | Severidad | Acción |
|---|---|---|---|
| C1 | **Verificar el fix de coordenadas (CRS).** Las posiciones reales se transforman con `to_GAMA_CRS` pero no se ha confirmado visualmente que C1–C5 y las estaciones caigan sobre las intersecciones reales. | 🔴 Verificar | Recargar el modelo en GAMA. Si quedan desplazadas de forma uniforme, ajustar `CRS_DATOS`; si la red no tuviera `.prj`, declarar el CRS al cargar el shapefile. |
| C2 | **Riesgo de datos sintéticos silenciosos.** `01_process_results.py` inventa datos calibrados si falta un CSV, lo que puede producir figuras 100 % sintéticas sin que se note. | 🟠 Media | Añadir flag `--strict` que aborte si algún escenario cae en sintético y marca de agua "DATOS SINTÉTICOS" en las figuras en ese modo. |
| C3 | **Rama `SUSPENDER` del GestorAMT es código muerto.** Con capacidad 8000/estación y ≤300 agentes, la saturación nunca llega a 0.85. | 🔵 Baja | Bajar la capacidad a la escala de agentes simulados, o documentar que es ilustrativa. |
| C4 | **Rendimiento si se sube a 500 agentes.** Las consultas `at_distance` (densidad por vía, percepción) son cuadráticas por ciclo. | 🔵 Baja | Cachear vecindarios / espaciar la percepción / pesar solo el subgrafo conexo. Solo relevante para corridas grandes. |

> **Mantener en sincronía:** al agregar una métrica hay que tocar tres sitios — el header
> `save [...]` del `init`, la fila de datos en `exportar_metricas` y `COLUMNAS_*` en
> `01_process_results.py`. Los dos modelos (E0/EB) no comparten código: un cambio de
> comportamiento suele tener que replicarse en ambos.

---

## 4. Ruta crítica al paper

```
[🔴] Correr E0_HET + EB completos (06:00–22:00)
        └─→ Regenerar pipeline con datos reales (01→02→03)
                ├─→ Tablas + Fig1–Fig5 definitivas
                ├─→ Fig equidad NSE (Δ Gini) + Fig recaudación/tarifa
                └─→ Resultados → Discusión (benchmark Londres)

[en paralelo] Plantilla Overleaf + Metodología (ya redactable)
```

Verificar el fix de coordenadas (C1) antes de la corrida final, para no rehacerla.

---

*Documento basado en revisión directa del código y los datos del repositorio `sma_quito`
al 13 de junio de 2026.*
