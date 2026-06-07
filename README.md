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
│   │   ├── TrafficBase_LaCarolina.gaml   # Escenario E0 — Baseline
│   │   └── EB_PeajeHorario.gaml          # Escenario EB — Peaje horario + GestorAMT BDI
│   ├── includes/
│   │   └── red_vial_la_carolina.*        # Shapefile de la red vial (OSM/QGIS)
│   └── outputs/
│       ├── E0_run1_metricas.csv          # Resultados exportados E0
│       └── EB_run1_metricas.csv          # Resultados exportados EB
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
git clone https://github.com/<tu-usuario>/sma_quito.git
cd sma_quito
```

### 2. Ejecutar la simulación en GAMA

1. Abrir GAMA Platform e importar el proyecto desde la carpeta `gama/`.
2. Ejecutar `TrafficBase_LaCarolina.gaml` → **Escenario E0 (Baseline)**.
3. Ejecutar `EB_PeajeHorario.gaml` → **Escenario EB (Peaje horario)**.
4. Los CSVs de resultados se exportan automáticamente en `gama/outputs/`.

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
