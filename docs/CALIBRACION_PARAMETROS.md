# Calibración de Parámetros — SMA Quito (modelos finales `*2`)

> Trazabilidad de cada parámetro del simulador: valor, fuente y clasificación según su origen.
> Cumple OE3 (`SMA.md §3.2`). Fuente de datos: `analysis/calibracion_parametros.csv`.
> Valores extraídos de `TrafficBase_LaCarolina2.gaml` / `EB_PeajeHorario2.gaml`.

**Clasificación del origen:**

| Etiqueta | Significado |
|---|---|
| **Empírico** | Dato real medido (AMT, INEC, EPMMQ, Ordenanza DMQ). |
| **Aproximado** | Derivado del perfil del DMQ, sin medición directa puntual. |
| **Propuesta** | Valor de la propuesta de política (Municipio) o del benchmark Londres. |
| **Calibrado** | Ajustado al régimen emergente del propio modelo (frente B). |
| **Supuesto** | Asunción razonable o tomada de literatura, no medida. |
| **Diseño** | Elección de configuración de la simulación. |

---

## 1. Perfil socioeconómico (NSE)

| Parámetro | Valor | Origen | Fuente |
|---|---|---|---|
| Proporción Alto / Medio / Bajo | 15 % / 45 % / 40 % | Aproximado | Perfil socioeconómico DMQ |
| `wtp` Alto / Medio / Bajo (USD) | 3.00 / 2.25 / 0.50 | **Supuesto** | Literatura / calibrado |
| Pesos (tiempo/costo/comodidad) Alto | 0.35 / 0.15 / 0.50 | **Supuesto** | Literatura |
| Pesos Medio | 0.35 / 0.35 / 0.30 | **Supuesto** | Literatura |
| Pesos Bajo | 0.20 / 0.65 / 0.15 | **Supuesto** | Literatura |
| Umbral congestión Alto/Medio/Bajo | 0.40 / 0.55 / 0.70 | **Supuesto** | Calibrado |

## 2. Flota por tipo de vehículo (300 inicial)

| Parámetro | Valor | Origen | Fuente |
|---|---|---|---|
| Moto / Auto / SUV / Bus / Carga | 45 / 165 / 45 / 30 / 15 | Aproximado | Parque automotor DMQ |
| Factor de ocupación de vía (PCU) | 0.3 / 1.0 / 1.5 / 3.0 / 2.5 | **Supuesto** | Estimación ingenieril |

## 3. Tercera placa

| Parámetro | Valor | Origen | Fuente |
|---|---|---|---|
| Fracción de flota restringida | 20 % | **Empírico** | Ordenanza Metropolitana DMQ / AMT |
| Ventana de restricción | 06:00–20:00 | **Empírico** | Ordenanza Metropolitana DMQ |

## 4. Peaje — escenario EB

| Parámetro | Valor | Origen | Fuente |
|---|---|---|---|
| Tarifa pico Auto | $2.00 | Propuesta | Municipio DMQ / benchmark Londres |
| Tarifa pico SUV / Carga | $3.00 | Propuesta | Diseño (impacto vial) |
| Tarifa pico Moto / Bus | $0.00 (exento) | Diseño | `SMA.md §7.2` |
| Tarifa fuera de pico | $0.00 | Diseño | Modelo London Congestion Charge |
| Franjas pico | 07:00–10:00 · 17:00–20:00 | Benchmark | London Congestion Charge |

## 5. Gestor AMT (peaje dinámico)

| Parámetro | Valor | Origen | Fuente |
|---|---|---|---|
| Cadencia de deliberación | 30 ciclos (~5 min) | **Supuesto** | Diseño |
| Vel. crítica / óptima (km/h) | 33 / 40 | Calibrado | Régimen del modelo (frente B) |
| Densidad v/c alta / baja | 0.25 / 0.20 | Calibrado | Régimen del modelo (frente B) |
| Saturación Metro (suspende) | 0.85 | **Supuesto** | Diseño |
| Tarifa mín. / máx. / paso | $0.50 / $3.00 / $0.25 | **Supuesto** | Diseño |

## 6. Metro de Quito

| Parámetro | Valor | Origen | Fuente |
|---|---|---|---|
| Tarifa del Metro | $0.45 | **Empírico** | Tarifa real Metro de Quito (EPMMQ) |
| Estaciones de la zona | 2 (Iñaquito, La Carolina) | **Empírico** | Metro de Quito |
| Capacidad por estación | 8 000/h | **Supuesto** | Estimación |
| Acceso al Metro (`metro_accesible`) | 60 % | **Supuesto** | Estimación de cobertura |
| Modal shift base desde auto | 15 % (~10 000 autos/día) | **Empírico** | Encuesta EPMMQ dic 2023–feb 2024 |

## 7. Cinemática y reloj

| Parámetro | Valor | Origen | Fuente |
|---|---|---|---|
| Velocidad de flujo libre (`VEL_LIBRE`) | 50 km/h | **Supuesto** | Diseño; emergente = 50 × coef. |
| Velocidad pico DMQ (referencia) | 14–18 km/h | **Empírico** | AMT / Google Traffic |
| Paso / horizonte / log | 10 s / 06:00–22:00 / 90 ciclos | Diseño | Diseño del modelo |

---

## Nota metodológica para el paper

La columna *Origen* es deliberadamente honesta: los parámetros **estructurales** (tercera placa,
tarifa del Metro, estaciones, modal shift base, velocidad de referencia) están **anclados a datos
reales** de la AMT, el INEC y la EPMMQ. Los parámetros **conductuales** (`wtp`, pesos de utilidad,
umbrales) son **supuestos calibrados** dentro de rangos plausibles de la literatura, no mediciones
directas — una limitación a declarar y una vía de trabajo futuro (calibrar con encuestas de
preferencias declaradas). Los umbrales del gestor son **calibrados al régimen del propio modelo**,
no a la realidad, por la brecha de velocidad emergente (~31–37 km/h vs. 14–18 km/h reales).
