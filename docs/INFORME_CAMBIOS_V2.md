# Informe de Cambios — SMA La Carolina V2 Heterogénea

**UCE · Sistemas Colaborativos 2026 · Fecha: junio 2026**

---

## Resumen ejecutivo

Esta versión introduce la **diferenciación de flota vehicular** en ambos escenarios del SMA:
el baseline sin peaje (`E0_HET`) y el escenario con peaje por franja horaria (`EB`).
Los vehículos ya no son agentes genéricos; cada uno porta un `tipo_vehiculo` que determina
su velocidad, impacto en la vía, política de peaje y comportamiento BDI.
El pipeline Python de análisis fue actualizado en consecuencia.

---

## 1. Cambios en `TrafficBase_LaCarolina_V2_Heterogeneo.gaml` (E0_HET)

### 1.1 Variables globales — reemplazo de conteo único por tipos

**Antes**

```gaml
int NB_CONDUCTORES <- 150;
float TARIFA_PICO  <- 2.00;
```

**Después**

```gaml
int NB_MOTOS  <- 45;   // ~15 % — DMQ INEC 2023
int NB_AUTOS  <- 165;  // ~55 %
int NB_SUVS   <- 45;   // ~15 %
int NB_BUSES  <- 30;   // ~10 % — exonerados
int NB_CARGAS <- 15;   // ~5 %
float TARIFA_PICO_AUTO <- 2.00;  // referencia nominal para comparación con EB
```

**Por qué:** la distribución por tipos permite calibrar el modelo con datos reales
del parque automotor DMQ y produce métricas de congestión más realistas
(buses y carga pesan más en la capacidad vial).

---

### 1.2 `global.init` — creación estructurada de la flota

**Antes:** un solo bloque `create ConductorBDI number: NB_CONDUCTORES`.

**Después:** cinco bloques independientes, cada uno asigna `tipo_vehiculo` antes
de que `init` del agente se ejecute:

```gaml
list<road> road_pool <- empty(roads_conectadas) ? list(road) : roads_conectadas;

create ConductorBDI number: NB_MOTOS  { tipo_vehiculo <- "MOTO";  ... }
create ConductorBDI number: NB_AUTOS  { tipo_vehiculo <- "AUTO";  ... }
create ConductorBDI number: NB_SUVS   { tipo_vehiculo <- "SUV";   ... }
create ConductorBDI number: NB_BUSES  { tipo_vehiculo <- "BUS";   ... }
create ConductorBDI number: NB_CARGAS { tipo_vehiculo <- "CARGA"; ... }
```

**Por qué:** GAML ejecuta el bloque `with:` / `{ }` de `create` _antes_ del `init`
del agente, por lo que `tipo_vehiculo` ya está disponible cuando se calculan
`speed`, `factor_capacidad_via`, etc.

---

### 1.3 `species road` — `nb_people` ponderado

**Antes**

```gaml
int nb_people <- 0 update: length(ConductorBDI at_distance 10);
```

**Después**

```gaml
float nb_people <- 0.0 update: sum(
    ConductorBDI at_distance 10 collect each.factor_capacidad_via);
```

**Por qué:** un bus ocupa el equivalente de 3 autos en la capacidad de una vía;
una moto equivale a 0.3. El cambio de `int` a `float` es necesario porque
`factor_capacidad_via` es continuo. La fórmula `exp(-nb_people / capacity)`
sigue funcionando sin cambios adicionales.

| Tipo  | `factor_capacidad_via` |
| ----- | ---------------------- |
| MOTO  | 0.3                    |
| AUTO  | 1.0                    |
| SUV   | 1.5                    |
| CARGA | 2.5                    |
| BUS   | 3.0                    |

---

### 1.4 `species ConductorBDI` — nuevos atributos

```gaml
string tipo_vehiculo        <- "AUTO";
float  factor_capacidad_via <- 1.0;
float  tarifa_efectiva      <- 0.0;
bool   exonerado_peaje      <- false;
```

- **`tipo_vehiculo`**: identidad del agente; determina todas las propiedades físicas.
- **`factor_capacidad_via`**: peso en `road.nb_people`; afecta la congestión emergente.
- **`tarifa_efectiva`**: tarifa que realmente paga el agente (0 si exonerado).
  Separa la tarifa _percibida_ (del PuntoControl) de la tarifa _aplicable_ al tipo.
- **`exonerado_peaje`**: `true` para BUS y MOTO; fuerza `tarifa_efectiva = 0`.

---

### 1.5 `ConductorBDI.init` — propiedades físicas por tipo

Se añadió un bloque al final del `init` (después de la asignación NSE) que
ajusta los atributos según `tipo_vehiculo`:

```gaml
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
    nse                  <- "BAJO";

} else if (tipo_vehiculo = "CARGA") {
    speed                <- max(10.0, speed - 40.0);
    factor_capacidad_via <- 2.5;
    metro_accesible      <- false;
    nse                  <- "BAJO";
}
```

**FIX aplicado en E0_HET (no en EB todavía — ver §4):** el bloque NSE se ejecuta
una sola vez.

---

### 1.6 `ConductorBDI.reflex percibir` — cálculo de `tarifa_efectiva`

```gaml
if (exonerado_peaje) {
    tarifa_efectiva <- 0.0;
} else if (tipo_vehiculo = "AUTO") {
    tarifa_efectiva <- tarifa_percibida;
} else if (tipo_vehiculo = "SUV") {
    float ratio <- (TARIFA_PICO_AUTO > 0.0) ? (TARIFA_PICO_SUV / TARIFA_PICO_AUTO) : 1.0;
    tarifa_efectiva <- tarifa_percibida * ratio;
} else if (tipo_vehiculo = "CARGA") {
    float ratio <- (TARIFA_PICO_AUTO > 0.0) ? (TARIFA_PICO_CARGA / TARIFA_PICO_AUTO) : 1.5;
    tarifa_efectiva <- tarifa_percibida * ratio;
}
```

En E0_HET, `tarifa_percibida` siempre es 0 (ningún PuntoControl cobra), pero la
estructura se mantiene para garantizar equivalencia de código entre escenarios.

---

### 1.7 `action decidir` — cortocircuito para BUS

```gaml
if (tipo_vehiculo = "BUS") {
    intencion          <- "RUTA_DIRECTA";
    count_ruta_directa <- count_ruta_directa + 1;
    chart_ruta_directa <- chart_ruta_directa + 1;
    count_directo_bajo <- count_directo_bajo + 1;
    decision_tomada    <- true;
    return;
}
```

El bus no evalúa utilidades ni considera el Metro. Representa transporte público
con ruta fija. Se contabiliza en `NSE_BAJO` para contadores, con la corrección
correspondiente en el pipeline Python (ver §3).

---

### 1.8 `aspect default` — visualización por tipo

**Colores base:**

| Tipo  | Color base      | Tamaño |
| ----- | --------------- | ------ |
| MOTO  | `#deepskyblue`  | 5      |
| AUTO  | `#dodgerblue`   | 8      |
| SUV   | `#mediumpurple` | 10     |
| CARGA | `#sienna`       | 12     |
| BUS   | `#limegreen`    | 14     |

**Overrides BDI:**

- `REROUTEAR` → `#orange`
- `METRO` → `#gold`

**Elevación z:** `draw circle(sz) at: location + {0, 0, 5}` eleva los vehículos
sobre el plano de las vías (z = 0), resolviendo el problema de solapamiento visual.

**`border: #black`** mejora la separación entre agentes adyacentes del mismo color.

**`species road`:** cambiado de `draw (shape + 5)` a `draw shape width: 2`
para reducir el grosor visual y dejar espacio visible a los vehículos.

---

### 1.9 CSV de salida — nombre y columnas

- Archivo: `E0_heterogeneo_metricas.csv` (antes `E0_run1_metricas.csv`)
- Etiqueta escenario: `"E0_HET"`
- **Columnas eliminadas:** `recaudacion_acum_usd`, `nb_restringidos_placa`
  (no aplican en E0 sin peaje ni restricción de placa)

---

### 1.10 Experimento — sliders por tipo de vehículo

```gaml
parameter "Motos (~15 %)"              var: NB_MOTOS   category: "Vehículos";
parameter "Autos particulares (~55 %)" var: NB_AUTOS   category: "Vehículos";
parameter "SUV / 4x4 (~15 %)"         var: NB_SUVS    category: "Vehículos";
parameter "Buses / T. público (~10 %)" var: NB_BUSES   category: "Vehículos";
parameter "Vehículos de carga (~5 %)"  var: NB_CARGAS  category: "Vehículos";
parameter "Tarifa AUTO pico USD [EB]"  var: TARIFA_PICO_AUTO  category: "[EB nominal]";
```

El slider de tarifa en E0 es nominal (siempre 0 durante la simulación); sirve
para comparar configuraciones entre escenarios sin cambiar de archivo.

---

## 2. Cambios en `EB_PeajeHorario.gaml`

Los cambios de §1.1 a §1.10 se replicaron en EB con las siguientes diferencias:

### 2.1 Tarifas diferenciadas por tipo

```gaml
float TARIFA_PICO_AUTO  <- 2.00;  // base (slider principal, gestor AMT)
float TARIFA_PICO_MOTO  <- 0.00;  // exonerada
float TARIFA_PICO_SUV   <- 2.00;  // igual al auto (diferenciable)
float TARIFA_PICO_CARGA <- 3.00;  // mayor impacto vial
// BUS: siempre 0, no requiere parámetro
```

### 2.2 `PuntoControl.tarifa_base` usa `TARIFA_PICO_AUTO`

```gaml
float tarifa_base <- 0.0 update: (es_hora_pico ? TARIFA_PICO_AUTO : TARIFA_VALLE);
```

El `GestorAMT` gestiona dinámicamente `tarifa_vigente` de todos los PuntoControl
a partir de esta base. Las tarifas de otros tipos se aplican en `percibir` de
cada `ConductorBDI` como ratio sobre `TARIFA_PICO_AUTO`.

### 2.3 Sliders de experimento — sección Peaje

```gaml
parameter "Tarifa AUTO pico (USD)"  var: TARIFA_PICO_AUTO  category: "Peaje";
parameter "Tarifa MOTO pico (USD)"  var: TARIFA_PICO_MOTO  category: "Peaje";
parameter "Tarifa SUV pico (USD)"   var: TARIFA_PICO_SUV   category: "Peaje";
parameter "Tarifa CARGA pico (USD)" var: TARIFA_PICO_CARGA category: "Peaje";
parameter "Peaje activo"            var: PEAJE_ACTIVO      category: "Peaje";
parameter "Gestor AMT activo"       var: GESTOR_ACTIVO     category: "Peaje";
```

### 2.4 `GestorAMT.ejecutar_intencion` — referencia corregida

```gaml
// Antes:
float tarifa_actual <- empty(activos) ? (es_hora_pico ? TARIFA_PICO : 0.0) ...
// Después:
float tarifa_actual <- empty(activos) ? (es_hora_pico ? TARIFA_PICO_AUTO : 0.0) ...
```

---

## 3. Cambios en `01_process_results.py`

### 3.1 Archivo de entrada E0

```python
ARCHIVOS_ESCENARIO = {
    "E0_HET": ["E0_heterogeneo_metricas.csv"],  # nuevo nombre
    "EB":     None,  # glob EB_run*
}
```

### 3.2 Relleno de columnas ausentes (`rellenar_columnas_faltantes`)

```python
if 'recaudacion_acum_usd' not in df.columns:
    df['recaudacion_acum_usd'] = 0.0
if 'nb_restringidos_placa' not in df.columns:
    df['nb_restringidos_placa'] = 0
```

Previene `KeyError` en `02_compare_scenarios.py` cuando E0_HET y EB tienen
esquemas de columnas distintos.

### 3.3 Corrección de equidad NSE — filtro de buses (`corregir_equidad_buses`)

Los buses siempre deciden `RUTA_DIRECTA` y siempre se contabilizan como `NSE_BAJO`,
inflando `directo_nse_bajo` de forma no representativa (su decisión no es libre).

**Corrección estimada:**

```python
BUS_FRACTION = NB_BUSES_DEFAULT / NB_TOTAL_DEFAULT  # 0.10

bus_directo_est = (total_bajo * BUS_FRACTION).round().astype(int)
df["directo_nse_bajo_corr"] = (df["directo_nse_bajo"] - bus_directo_est).clip(lower=0)
df["metro_nse_bajo_corr"]   = df["metro_nse_bajo"]    # buses no van al metro
df["rerouta_nse_bajo_corr"] = df["rerouta_nse_bajo"]  # buses no reroutean
```

Las columnas originales se conservan. Para el cálculo del **Δ Gini modal** usar
las columnas `*_corr`.

---

## 4. Estado final por archivo

| Archivo                                      | Estado                   | Bugs críticos |
| -------------------------------------------- | ------------------------ | ------------- |
| `TrafficBase_LaCarolina_V2_Heterogeneo.gaml` | ✅ Listo para simulación | Ninguno       |
| `EB_PeajeHorario.gaml`                       | ✅ Listo para simulación | Ninguno       |
| `01_process_results.py`                      | ✅ Listo                 | Ninguno       |

---

## 5. Flujo de datos entre componentes

```
GAMA Platform
├── E0_HET → gama/outputs/E0_heterogeneo_metricas.csv
│             19 columnas (sin recaudacion ni restringidos_placa)
│
└── EB     → gama/outputs/EB_run1_metricas.csv
              22 columnas (incluye tarifa_vigente_usd, recaudacion, restringidos)

Python Pipeline
├── 01_process_results.py
│   ├── Lee E0_heterogeneo_metricas.csv  (etiqueta: E0_HET)
│   ├── Lee EB_run*_metricas.csv         (etiqueta: EB)
│   ├── Rellena columnas ausentes en E0_HET con 0
│   ├── Genera directo_nse_bajo_corr (filtra buses)
│   └── Salidas: E0_HET_processed.csv, EB_processed.csv, combined.csv
│
├── 02_compare_scenarios.py
│   └── Usa columnas *_corr para Δ Gini modal
│
└── 03_generate_figures.py
    └── Figuras PNG/PDF 300 DPI para el paper
```

---

_Informe generado automáticamente — SMA Quito UCE 2026_
