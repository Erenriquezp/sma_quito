# Estado del Proyecto

> Foto del proyecto frente a sus objetivos (`SMA.md §3.2`). **Última revisión:** 29 jun 2026.
> Detalle histórico en `INFORME_CAMBIOS_V2.md` y los commits.

## En una línea

Modelos finales (`*2`), pipeline y paper completos. **El bloqueante quedó resuelto:** EB ya
corre el día completo (06:15→22:00, 64 filas) y es comparable con E0. El pipeline `01→02→03`
se regeneró con datos reales (sin sintéticos). Resultado honesto: la reducción de flujo en
hora pico es **−17.2 %**, por debajo de la meta de −20 %, pero el modal shift y la velocidad
mejoran. Quedan reproducibilidad en batch y el porte a Overleaf.

---

## Resultados finales E0 vs EB (corrida 29 jun 2026)

Ambos escenarios: día completo, misma demanda (1928 veh). Fuente: CSV reales de GAMA.

| Métrica (hora pico) | E0 | EB | Δ | ¿Meta? |
|---|--:|--:|--:|:--:|
| Flujo en polígono (veh/h) | 3635.7 | 3011.9 | **−17.2 %** | ✗ (meta ≥20 %) |
| Velocidad media (km/h) | 31.4 | 32.1 | +2.3 % | ✓ (>0) |
| Modal shift → Metro | 9.8 % | 14.3 % | +45 % | ✓ (>5 %) |
| Desplazamiento periférico | 344.5 | 525.9 | +52.7 % | ✗ (efecto colateral) |

- **Significancia:** solo el modal shift es estadísticamente significativo (t-test p=0.004);
  flujo (p=0.78) y velocidad (p=0.74) no lo son.
- **Peaje dinámico:** `tarifa_vigente` varía en la corrida (0 → 1.0 → 1.75 → 2.0 → 2.25 → 2.5 → 3.0).
- **Tarifa diferenciada:** Auto $7334 / SUV $2584 / Carga $2277; Moto y Bus exentos ($0).
  Recaudación total **$12 194**.
- **Veredicto de hipótesis:** NO confirmada (17.2 % < 20 %). Es un hallazgo realista — el peaje
  alivia el pico vía modal shift, no por reducción masiva de vehículos; parte del tráfico se
  desplaza a la periferia en lugar de desaparecer.

---

## Avance por objetivo (`SMA.md §3.2`)

| # | Objetivo | Estado |
|---|---|:--:|
| **OE1** | Polígono con datos GIS reales | 🟢 Casi |
| **OE2** | Conductores BDI por NSE + tipo de vehículo, 3 decisiones | ✅ |
| **OE3** | Tercera placa + calibración AMT | 🟡 Parcial |
| **OE4** | Ejecutar y comparar E0 vs EB | ✅ |
| **OE5** | Paper (IEEE) | 🟡 Pendiente |

---

## Ya resuelto ✅

- **Corrida completa de EB (ex-bloqueante):** EB ya llega al `do pause` de las 22:00 (64 filas,
  06:15→22:00), igual que E0 → ambos comparables. Pipeline `01→02→03` regenerado con esos CSV
  reales; las 7 figuras se reescribieron **sin marca de agua** (datos no sintéticos, `--strict` pasa).
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

### 1. 🟡 OE5 — actualizar Resultados/Discusión del paper y portar a Overleaf

Con los datos reales A+B ya disponibles, falta **escribir Resultados/Discusión en `PAPER.md`**
con las cifras finales (incluida la hipótesis NO confirmada, −17.2 %) y **portar el paper a
LaTeX/Overleaf (IEEE)** insertando `fig1–fig7` y citando la tabla de calibración.

### 2. 🟠 Frente C — reproducibilidad en batch

Los 5 peajes se colocan por **doble clic y no se persisten**; la `zona_peaje` es su envolvente y la
velocidad se mide dentro. Otra colocación → otros resultados, y los modelos `*2` no corren en
autorun/batch. **Acción:** persistir los puntos (shapefile/CSV) y cargarlos en `init`.

### 3. 🟢 OE3 — calibración AMT formal (hecho)

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
| C6 | Goteo de recaudación SUV/Carga en valle (~$570, tarifa rezagada en la transición de banda). No afecta flujo/velocidad/modal-shift; infla algo los totales por tipo. | Recalcular `tarifa_efectiva` al cruzar (no reusar el valor de pico) o documentar como artefacto menor. |

> **Al agregar métricas:** sincronizar tres sitios — header `save` del `init`, fila de
> `exportar_metricas` y `COLUMNAS_*` en `01_process_results.py`.
