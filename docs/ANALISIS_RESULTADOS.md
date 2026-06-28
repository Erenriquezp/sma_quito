# Análisis de Resultados — Peaje La Carolina (E0 vs EB)

Simulación BDI multi-agente, GAMA Platform. Comparación entre el escenario
**E0** (baseline, sin peaje) y **EB** (peaje por franja horaria, modelo London
Congestion Charge). Datos reales de simulación, ventana 06:15–22:00 (64
intervalos de 15 min por escenario).

> Generado a partir de `analysis/results/tabla_comparativa.csv` y
> `tabla_benchmark.csv`. Para reproducir: ejecutar `01`→`02`→`03` en
> `analysis/scripts/`.

---

## 1. Resumen ejecutivo

El peaje produce efectos **en la dirección esperada durante la hora pico**
(menos flujo, más velocidad, más trasvase al Metro), pero la magnitud es
**insuficiente** frente a la meta. La reducción de flujo en hora pico fue de
**−6.9%**, lejos del **≥20%** planteado y del −27% de Londres 2003.

**Veredicto de hipótesis (reducción ≥ 20%): ✗ NO CONFIRMADA.**

El único efecto estadísticamente significativo es el modal shift al Metro
(p = 0.013). Flujo y velocidad no alcanzan significancia.

---

## 2. Tabla comparativa

| Métrica | E0 | EB | Δ % | ¿Mejora? |
|---|---:|---:|---:|:---:|
| Flujo en polígono — total | 2134.31 | 2141.62 | +0.34% | ✗ |
| **Flujo en polígono — hora pico** | 2008.15 | 1869.38 | **−6.91%** | ✓ |
| Desplazamiento periférico (flujo externo) | 129.69 | 149.56 | +15.33% | ✗ |
| Velocidad media — total | 33.87 | 33.77 | −0.32% | ✗ |
| **Velocidad media — hora pico** | 33.89 | 34.31 | **+1.25%** | ✓ |
| Modal shift → Metro — total | 4.52% | 3.12% | −31.08% | ✗ |
| **Modal shift → Metro — hora pico** | 5.24% | 7.65% | **+46.04%** | ✓ |
| Δ Gini modal — promedio | 0.11 | 0.11 | +2.48% | ✗ |
| Δ Gini modal — hora pico | 0.14 | 0.19 | +40.34% | ✗ |
| Recaudación estimada | 0.00 | 542.62 USD/h | — | — |

*Unidades: flujo en veh/h, velocidad en km/h, Gini índice 0–1.*

---

## 3. Lectura por dimensión

### Movilidad (congestión)
- **Hora pico sí responde**: −6.9% de flujo y +1.25% de velocidad. El
  mecanismo BDI del peaje funciona, pero el efecto es débil.
- **Efecto fuga**: el desplazamiento periférico sube **+15.3%**. Parte del
  tráfico no desaparece, se reasigna a vías externas a la zona — un costo
  ambiental/de congestión que se traslada al perímetro.
- **Fuera de pico no hay efecto neto** (flujo +0.34%, velocidad −0.32%),
  como se espera: la tarifa solo está activa en las franjas pico.

### Cambio modal
- El trasvase al Metro en hora pico crece **+46%** (5.24% → 7.65%) y es el
  **único resultado estadísticamente significativo** (p = 0.013).
- La caída del modal shift total (−31%) es artefacto de promediar con las
  horas valle, donde el peaje no aplica; la métrica relevante es la de pico.

### Equidad (Gini modal NSE)
- El Gini modal en hora pico sube de 0.14 a 0.19 (**+40%**): el peaje
  **incrementa la desigualdad** de acceso modal entre niveles
  socioeconómicos en la franja tarifada. Punto a vigilar para el paper.
- *(Calculado sobre columnas `*_corr`, con la contribución de buses ya
  descontada.)*

### Recaudación
- ~542 USD/h simulada (8682 USD acumulados en EB). Coherente con tarifa
  $2.00 y volumen de pagadores en pico.

---

## 4. Benchmark London Congestion Charge 2003

| Indicador | Londres 2003 | Meta Quito | Modelo EB | ¿Cumple? |
|---|---|---|---|:---:|
| Reducción vehicular (pico) | −27% | ≥ −20% | −6.9% | ✗ recalibrar |
| Mejora velocidad (pico) | +20% | > 0% | +1.2% | ✓ |
| Modal shift a transporte público | ~12% | > 5% | ~7.6% (Metro) | ✓ |
| Tarifa inicial | £5 ≈ $6.0 USD | $2.00 (propuesto) | $2.00 | — |

Se cumplen 2 de 3 metas direccionales, pero **falla la principal**
(reducción de flujo).

---

## 5. Significancia estadística (t-test E0 vs EB)

| Métrica | p-valor | Resultado |
|---|---:|---|
| Flujo en polígono | 0.946 | no significativo |
| Velocidad media | 0.638 | no significativo |
| Modal shift Metro (pct_metro) | **0.013** | **significativo ✓** |

---

## 6. Conclusiones

1. **El instrumento funciona pero está subdimensionado.** Todos los signos en
   hora pico van en la dirección teórica; la magnitud no alcanza la meta.
2. **La tarifa es la principal sospechosa**: $2.00 vs ~$6.0 USD de Londres.
   Una tarifa baja explica una elasticidad de demanda débil.
3. **Hay efecto fuga al perímetro** (+15%) que conviene reportar como
   externalidad y considerar en el diseño de la zona.
4. **Trade-off de equidad**: el peaje mejora la movilidad agregada en pico
   pero empeora el Gini modal (+40%).

### Recomendaciones de recalibración
- Subir la **tarifa pico** ($2.00 → rango $3–6) y re-correr E B.
- Revisar la distribución de **disposición a pagar (`wtp`)** y los
  **umbrales de congestión** por NSE en los modelos GAMA.
- Evaluar mecanismos de mitigación de equidad (exenciones/descuentos por NSE)
  para contener el alza del Gini.

---

*Fuentes: `analysis/results/tabla_comparativa.csv`, `tabla_benchmark.csv`,
`combined.csv`. Figuras en `analysis/figures/` (fig1–fig6, PNG + PDF 300 DPI).*
