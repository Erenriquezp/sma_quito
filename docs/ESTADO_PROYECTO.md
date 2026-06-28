# Estado del Proyecto

> Foto del proyecto frente a sus objetivos (`SMA.md §3.2`). **Última revisión:** 27 jun 2026.
> Detalle histórico en `INFORME_CAMBIOS_V2.md` y los commits.

## En una línea

Modelos finales (`*2`), pipeline y paper completos. Las tarifas diferenciadas por tipo y el
peaje dinámico ya están **implementados y validados en código**. El bloqueante real es
**una corrida completa de EB (06:00–22:00)** con el modelo actual: la última se cortó a las 7:45.

---

## Avance por objetivo (`SMA.md §3.2`)

| # | Objetivo | Estado |
|---|---|:--:|
| **OE1** | Polígono con datos GIS reales | 🟢 Casi |
| **OE2** | Conductores BDI por NSE + tipo de vehículo, 3 decisiones | ✅ |
| **OE3** | Tercera placa + calibración AMT | 🟡 Parcial |
| **OE4** | Ejecutar y comparar E0 vs EB | 🟡 Parcial |
| **OE5** | Paper (IEEE) | 🟡 Pendiente |

---

## Ya resuelto ✅

- **Pipeline `01→02→03`** corriendo con datos reales (tablas, t-tests, Δ Gini, 7 figuras).
- **Paper** (`PAPER.md`) y análisis (`ANALISIS_RESULTADOS.md`) alineados al modelo final.
- **Frente A — tarifas diferenciadas por tipo:** implementado y validado (recaudación por tipo en
  el CSV; SUV/Carga pagan ≈1.5× el auto; Moto/Bus exentos).
- **Frente B — peaje dinámico:** gestor corregido (densidad v/c, umbrales recalibrados, sliders).
  Validado: `tarifa_vigente` ya varía en la corrida (antes clavada en $0/$2).
- **Calibración (OE3):** `analysis/calibracion_parametros.csv` + `docs/CALIBRACION_PARAMETROS.md`.
- **C2 — guardas de datos sintéticos:** `01 --strict` aborta si falta un CSV real; las figuras (03)
  llevan marca de agua "DATOS SINTÉTICOS" cuando los datos no son reales. (De paso, `fig4` ahora
  tolera corridas parciales sin romperse.)

---

## Lo que falta de verdad

### 1. 🔴 Corrida completa de EB — bloqueante

La última corrida de EB se **cortó a las 7:45** (7 filas en vez de 64), así que E0 (día completo)
y EB no son comparables todavía. Hay que correr EB en GAMA hasta el `do pause` de las 22:00 con
los defaults actuales del gestor (`vel. óptima = 40`, `densidad alta = 0.25`), colocando los 5
puntos de control C# por doble clic al inicio. Luego regenerar `01→02→03`.

Desbloquea: tablas y `fig1–fig7` definitivas, recaudación dinámica por tipo, y la actualización de
Resultados/Discusión en `PAPER.md` con datos reales de A+B.

### 2. 🟠 Frente C — reproducibilidad en batch

Los 5 peajes se colocan por **doble clic y no se persisten**; la `zona_peaje` es su envolvente y la
velocidad se mide dentro. Otra colocación → otros resultados, y los modelos `*2` no corren en
autorun/batch. **Acción:** persistir los puntos (shapefile/CSV) y cargarlos en `init`.

### 3. 🟡 OE5 — paper a Overleaf

`PAPER.md` está completo en Markdown; falta **portarlo a LaTeX/Overleaf (IEEE)** e insertar las
figuras finales.

### 4. 🟢 OE3 — calibración AMT formal (hecho)

Generado el artefacto de trazabilidad: `analysis/calibracion_parametros.csv` (43 parámetros) y la
versión legible `docs/CALIBRACION_PARAMETROS.md`, que clasifican cada valor por origen (Empírico /
Aproximado / Propuesta / Calibrado / Supuesto / Diseño) con su fuente. Pendiente solo **citar la
tabla en la Metodología del paper**.

---

## Correcciones menores 🔵

| # | Tema | Acción |
|---|---|---|
| C3 | Rama `SUSPENDER` del gestor casi nunca se activa (Metro no satura). | Bajar capacidad del Metro o documentar que es ilustrativa. |
| C5 | Conviven 4 modelos; un cambio se replica E0↔EB a mano. | Eliminar los legado si no se usan. |

> **Al agregar métricas:** sincronizar tres sitios — header `save` del `init`, fila de
> `exportar_metricas` y `COLUMNAS_*` en `01_process_results.py`.
