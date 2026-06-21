# Simulación Multiagente del Impacto de una Zona de Cobro por Congestión — Parque La Carolina, Quito

> **BDI-based Multi-Agent Simulation of Congestion Pricing around Parque La Carolina:  
> A Policy Evaluation Tool for Quito's Urban Mobility**

[![GAMA Platform](https://img.shields.io/badge/GAMA-Platform%202.0-blue)](https://gama-platform.org)
[![Python](https://img.shields.io/badge/Python-3.10%2B-yellow)](https://www.python.org)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![UCE](https://img.shields.io/badge/UCE-Sistemas%20Colaborativos%202026-red)](https://www.uce.edu.ec)

---

## Descripción del Proyecto

Este proyecto implementa un Sistema Multiagente (SMA) con arquitectura **BDI (Beliefs–Desires–Intentions)** e integración de datos geoespaciales reales para simular y evaluar el impacto de una zona de cobro por congestión vehicular en el sector del **Parque La Carolina**, Quito – Ecuador.

Se comparan dos escenarios:

| Escenario | Descripción |
|-----------|-------------|
| **E0 — Baseline** | Estado actual sin peaje. Restricción de tercera placa activa, Metro de Quito disponible. |
| **EB — Peaje franja horaria** | Cobro de $2.00 USD en horas pico (07:00–10:00 y 17:00–20:00), replicando el modelo del *London Congestion Charge* (2003). |

La hipótesis principal es que el peaje reduce el flujo vehicular en el polígono en **al menos un 20 %**, incrementa el uso del Metro de Quito y no genera un desplazamiento crítico de tráfico hacia vías periféricas.

---

## Estructura del Repositorio

```
sma_quito/
├── gama/
│   ├── models/
│   │   ├── TrafficBase_LaCarolina2.gaml  # Escenario E0 — Baseline (modelo final, zona configurable)
│   │   ├── EB_PeajeHorario2.gaml         # Escenario EB — Peaje horario + GestorAMT BDI (modelo final)
│   │   ├── TrafficBase_LaCarolina.gaml   # E0 — versión fija original (legado)
│   │   └── EB_PeajeHorario.gaml          # EB — versión fija original (legado)
│   ├── includes/
│   │   └── *.shp                         # Shapefiles de red vial intercambiables (OSM/QGIS)
│   └── outputs/
│       ├── E0_metricas.csv               # Resultados exportados E0
│       └── EB_metricas.csv               # Resultados exportados EB
├── analysis/
│   ├── scripts/
│   │   ├── 01_process_results.py         # Carga y limpieza de CSVs de GAMA
│   │   ├── 02_compare_scenarios.py       # Comparación E0 vs EB + benchmark Londres
│   │   └── 03_generate_figures.py        # Figuras para el paper (PNG/PDF, 300 DPI)
│   ├── results/                          # CSVs procesados (generados por scripts)
│   └── figures/                          # Figuras del paper (generadas por scripts)
└── docs/
    └── SMA.md                            # Documento completo del proyecto
```

---

## Agentes del Sistema

| Agente | Arquitectura | Instancias | Rol |
|--------|-------------|------------|-----|
| `ConductorBDI` | BDI + Función de utilidad | 150–500 | Decide pagar, reroutear o cambiar al Metro según perfil NSE |
| `PuntoControl` | Reactivo → BDI | 5 | Cobra el peaje en los accesos al polígono |
| `EstacionMetro` | Reactivo/Pasivo | 2 | Atractor de modal shift (Iñaquito, La Carolina) |
| `GestorAMT` | BDI deliberativo | 1 | Ajuste dinámico de tarifas (activo en EB) |
| `road` | Pasivo (entorno) | Red completa | Red vial importada desde QGIS/OSM |

---

## Inicio Rápido

### Prerrequisitos

- **GAMA Platform 2.0** → [Descargar](https://gama-platform.org/download)
- **Python 3.10+** con las dependencias de análisis
- (Opcional) **QGIS 3.x** para regenerar el shapefile de la red vial

### 1. Clonar el repositorio

```bash
git clone https://github.com/Erenriquezp/sma_quito.git
cd sma_quito
```

### 2. Ejecutar la simulación en GAMA

1. Abrir GAMA Platform e importar el proyecto desde la carpeta `gama/`.
2. Ejecutar `TrafficBase_LaCarolina2.gaml` → **Escenario E0 (Baseline)**.
3. Ejecutar `EB_PeajeHorario2.gaml` → **Escenario EB (Peaje horario)**.
4. Los CSVs de resultados se exportan automáticamente en `gama/outputs/`
   (`E0_metricas.csv` y `EB_metricas.csv`).

> Para el paso a paso de operación (colocar la zona de cobro, leer el HUD, ajustar parámetros)
> ver **[Cómo usar el simulador](#cómo-usar-el-simulador)** más abajo.

### 3. Instalar dependencias de Python

```bash
pip install -r requirements.txt
```

### 4. Ejecutar el pipeline de análisis

```bash
cd analysis/scripts

python 01_process_results.py    # Normaliza los CSVs de GAMA
python 02_compare_scenarios.py  # Genera tablas comparativas E0 vs EB
python 03_generate_figures.py   # Genera las figuras del paper (PNG + PDF)
```

Las figuras se guardan en `analysis/figures/` y las tablas en `analysis/results/`.

---

## Cómo usar el simulador

Tutorial breve para operar los modelos finales (`TrafficBase_LaCarolina2.gaml` y
`EB_PeajeHorario2.gaml`) dentro de la interfaz de GAMA.

### 1. Abrir el experimento

En el explorador de GAMA, abre el `.gaml` y haz clic en el botón ▶ junto al
`experiment` para lanzar la vista de simulación.

### 2. Elegir el mapa y los parámetros (panel izquierdo)

Antes de iniciar, en el panel **Parameters**:

- **Seleccionar Entorno Vial** (`nombre_mapa`) — elige el shapefile: La Carolina,
  Carolina alterno o Quicentro Sur.
- **Tamaño vehículos** (categoría *Vista*) — ajusta el tamaño de los iconos en el mapa.
- En **EB**, las tarifas por tipo (auto, SUV, carga) en hora pico.

### 3. Definir la zona de cobro (doble clic)

La zona de cobro **no está fija**: se dibuja con los puntos de control que colocas tú.

1. **Doble clic** sobre el mapa en cada acceso al polígono donde quieras un peaje
   (recomendado: ~5 puntos, C1–C5).
2. La **zona de cobro** aparece como una *manta* azul: el polígono convexo que une tus puntos.
3. Coloca los puntos **antes** de dejar correr la simulación.

> ⚠️ Los puntos colocados por clic **no se guardan** entre corridas: hay que volver a
> dibujarlos cada vez. Por eso, para resultados reproducibles del paper conviene una sola
> corrida continua.

### 4. Leer la pantalla

- **Vías (mapa de calor):** gris-azulado = flujo libre · ámbar/coral = congestión.
- **Vehículos:** icono orientado a su rumbo; el halo indica su estado (dentro/fuera de la zona).
- **Estaciones Metro:** atractores de cambio modal.
- **HUD (overlay):** KPIs en vivo, línea de tiempo del día (06–22 h) con franjas pico, e
  indicador de día. En **EB** se añade la tarifa vigente y el bloque "peaje por tipo".

### 5. Dejar correr y exportar

La simulación arranca a las 06:00 y se **pausa sola a las 22:00**. Durante la corrida exporta
métricas cada ~15 min de simulación a `gama/outputs/` (`E0_metricas.csv` / `EB_metricas.csv`).
Al terminar, pasa al [pipeline de análisis](#4-ejecutar-el-pipeline-de-análisis).

---

## Métricas de Evaluación

| Métrica | Unidad | Benchmark (Londres 2003) |
|---------|--------|--------------------------|
| Reducción vehicular en polígono (hora pico) | % | −27 % |
| Mejora de velocidad media (hora pico) | % | +20 % |
| Modal shift hacia transporte público | % | ~12 % |
| Desplazamiento hacia vías periféricas | veh/h | Reducción también en vías externas |

---

## Datos de Calibración

- **Red vial**: OpenStreetMap exportada con QGIS 3.x (EPSG:32717 — UTM 17S)
- **Flota vehicular DMQ**: 600 000+ vehículos (INEC, Anuario de Transporte 2023)
- **Metro de Quito**: ~170 000 viajes/día; 15 % provenientes de vehículo particular (EPMMQ, feb. 2025)
- **Restricción vehicular**: Tercera placa (~20 % de la flota en días hábiles)

---

## Equipo

Proyecto académico de la asignatura **Sistemas Colaborativos (TGP09BFT03)** — Noveno semestre,  
**Carrera de Computación, Facultad de Ingeniería y Ciencias Aplicadas, Universidad Central del Ecuador**.

Docente: **Luis Felipe Borja** | Período: 2026

---

## Licencia

Este proyecto se distribuye bajo la licencia [MIT](LICENSE).  
Los datos geoespaciales provienen de OpenStreetMap (© OpenStreetMap contributors, ODbL).
