# Estado del Proyecto

> Foto del proyecto frente a sus objetivos (`SMA.md §3.2`). **Última revisión:** 20 jun 2026.
> Para el detalle histórico ver `INFORME_CAMBIOS_V2.md` y los commits.

## En una línea

Arquitectura, modelos y pipeline **completos**. El único bloqueante de resultados es **correr
ambos escenarios completos (06:00–22:00)** con los modelos finales: hoy solo hay corridas
parciales de la mañana y el pipeline cae en datos sintéticos.

---

## Avance por objetivo (`SMA.md §3.2`)

| # | Objetivo | Estado | Qué falta |
|---|---|:--:|---|
| **OE1** | Polígono con datos GIS reales | 🟢 Casi | Polígono de cobro como **capa de área GIS** para el paper; densidad **INEC** explícita. |
| **OE2** | Conductores BDI por NSE, 3 decisiones | ✅ Completo | — |
| **OE3** | Tercera placa + calibración AMT | 🟡 Parcial | **Calibración formal AMT**: CSV de parámetros BDI + tabla (hoy *hardcoded*). |
| **OE4** | Ejecutar y comparar E0 vs EB | 🔴 Bloqueado | **Corridas completas** (ver abajo) + métrica de **equidad (Δ Gini)**. |
| **OE5** | Paper Overleaf (IEEE) | 🟡 Pendiente | Plantilla LaTeX + redactar las 6 secciones (`SMA.md §15`); Resultados/Discusión dependen de OE4. |

---

## Lo que falta

### 🔴 Bloqueante único — datos completos

Correr **E0 y EB (modelos `*2` finales)** completos (06:00–22:00, hasta `do pause`), generando
`E0_metricas.csv` y `EB_metricas.csv`, y regenerar el pipeline (`01→02→03`). Los CSV actuales son
parciales y de los modelos legado; hasta regenerarlos, `01` cae en **datos sintéticos**.

Desbloquea: estabilizar el % de reducción (osciló −18…−27 % en parciales), incluir el **pico
vespertino** (17–20 h, hoy ausente) y dar potencia a los t-tests.

### 🟡 Análisis y paper

- Figura de **equidad NSE (Δ Gini modal)** con las columnas `*_corr` → cierra OE4.
- Figura de **recaudación y tarifa dinámica** del GestorAMT (datos disponibles en EB).
- **Plantilla LaTeX Overleaf (IEEE)** con las 6 secciones de `SMA.md §15` → OE5.
- Sección **Discusión** con el benchmark Londres.

### 🟢 Entregables y calidad

- **CSV de parámetros BDI** por NSE + **tabla de calibración AMT** → cierra OE3.
- **Polígono de cobro como capa GIS** + densidad INEC → cierra OE1.
- **Persistir la zona configurable** (shapefile/CSV de puntos de control) para que los modelos
  `*2` sean reproducibles fuera del modo interactivo (hoy los puntos por clic no se guardan).

---

## Correcciones pendientes 🔧

| # | Tema | Sev. | Acción |
|---|---|:--:|---|
| C2 | `01` inventa datos sintéticos si falta un CSV → figuras 100 % falsas sin avisar. | 🟠 | Flag `--strict` que aborte + marca de agua "DATOS SINTÉTICOS". |
| C3 | Rama `SUSPENDER` del GestorAMT es código muerto (saturación nunca llega a 0.85). | 🔵 | Bajar la capacidad a la escala de agentes, o documentar que es ilustrativa. |
| C4 | Consultas `at_distance` cuadráticas; lento si se sube a 500 agentes. | 🔵 | Cachear vecindarios / espaciar percepción. Solo para corridas grandes. |
| C5 | Conviven 4 modelos; un cambio de comportamiento debe replicarse E0↔EB a mano. | 🔵 | Considerar eliminar los legado si no se usan. |

> **Sincronía al agregar métricas:** tocar tres sitios — header `save [...]` del `init`, fila de
> datos en `exportar_metricas` y `COLUMNAS_*` en `01_process_results.py`.

---

## Ruta crítica al paper

```
[🔴] Correr E0 + EB (modelos *2) completos (06:00–22:00)
        └─→ Regenerar pipeline con datos reales (01→02→03)
                ├─→ Tablas + Fig1–Fig5 definitivas
                ├─→ Fig equidad NSE (Δ Gini) + Fig recaudación/tarifa
                └─→ Resultados → Discusión (benchmark Londres)

[en paralelo] Plantilla Overleaf + Metodología (ya redactable)
[en paralelo] Entregables P2: CSV de parámetros BDI + tabla calibración AMT
```
