# Estado del Proyecto — SMA Movilidad Urbana Quito
## Auditoría técnica: qué está listo y qué falta

> **Fecha de revisión:** Junio 2026  
> **Basado en:** `docs/SMA.md`, código GAML en `gama/models/`, scripts Python en `analysis/scripts/`, datos en `gama/outputs/`

---

## Resumen ejecutivo

El proyecto tiene una base sólida: la arquitectura BDI está implementada, la red vial está integrada y el pipeline de análisis Python está completo. El análisis a continuación se basa **estrictamente en el código existente** — se describe lo que el código hace, los datos que produce y las pruebas que deben ejecutarse para validar los resultados antes de sacar conclusiones para el paper.

Los puntos que requieren atención antes de tener resultados publicables son:

- Las simulaciones E0 y EB deben ejecutarse de forma completa y con parámetros ajustados para producir comportamiento BDI observable.
- El CSV del Escenario EB presenta un encabezado duplicado que afecta la lectura automática con Python.
- Hay un nombre de estación Metro inconsistente entre el código y la documentación.
- El modelo actualmente solo contempla un tipo genérico de vehículo; la diferenciación por categoría (moto, auto, vehículo grande/bus) es una mejora pendiente con impacto directo en el realismo y la equidad del análisis.

---

## 1. MÓDULO GAML — Modelos de Simulación

### 1.1 Infraestructura base

| Componente | Estado | Detalle |
|---|---|---|
| Carga del shapefile `red_vial_la_carolina.shp` | ✅ **Listo** | Se carga correctamente, GAMA lo procesa |
| Extracción del componente conexo principal | ✅ **Listo** | `main_connected_component()` implementado con fallback doble |
| Reloj de simulación (06:00–22:00, step 10 s) | ✅ **Listo** | `minuto_actual` calculado desde `cycle * step` correctamente |
| Detección de hora pico (07–10 h y 17–20 h) | ✅ **Listo** | Flags `es_hora_pico`, `HORA_PICO_MAT_*`, `HORA_PICO_VES_*` |
| Exportación de métricas a CSV (cada 15 min sim) | ✅ **Listo** | `INTERVALO_LOG = 90` ciclos, encabezado escrito en `init` |
| Visualización 3D + charts en tiempo real | ✅ **Listo** | 4 displays: mapa, flujo vehicular, pie BDI, velocidad media |
| Parámetros interactivos en el experimento | ✅ **Listo** | Sliders de conductores, día semana, tarifa pico ajustables en tiempo real |

### 1.2 Species `ConductorBDI`

| Componente | Estado | Detalle |
|---|---|---|
| Perfil NSE (ALTO / MEDIO / BAJO) con WTP calibrado | ✅ **Listo** | Proporciones 15 % / 45 % / 40 %; WTP $3.00 / $2.25 / $0.50 |
| Pesos de utilidad diferenciados por NSE (w₁, w₂, w₃) | ✅ **Listo** | NSE ALTO: comodidad dominante; NSE BAJO: costo dominante |
| Restricción de tercera placa como precondición BDI | ✅ **Listo** | 20 % de la flota restringida en días hábiles |
| Percepción de tarifa del PuntoControl cercano | ✅ **Listo** | `ask PuntoControl at_distance 300` en `reflex percibir` |
| Percepción de congestión (`nivel_congestion`) | ✅ **Listo** | Fracción de vías con `speed_coeff ≤ 0.5` en radio 200 m |
| Umbral de congestión diferenciado por NSE | ✅ **Listo** | ALTO: 0.40, MEDIO: 0.55, BAJO: 0.70 |
| Función de utilidad `u_directa` | ✅ **Listo** | Penaliza tarifa > WTP devolviendo −0.5; incluye penalty de congestión |
| Función de utilidad `u_reroutear` | ✅ **Listo** | Bonus de congestión para hacerla atractiva cuando hay tráfico |
| Función de utilidad `u_metro` | ✅ **Listo** | Desactivada si `metro_accesible = false`; bonus de congestión |
| Movimiento sobre `road_network` con pesos | ✅ **Listo** | `goto` con `move_weights`, detección de atasco por `t_sin_avanzar` |
| Contadores desagregados por NSE (directo / metro / rerouta) | ✅ **Listo** | 9 contadores separados, se exportan al CSV |
| **Diferenciación por tipo de vehículo** | ❌ **Falta** | Todos los agentes son del mismo tipo genérico. Ver sección 3.6 |

### 1.3 Species `PuntoControl`

| Componente | Estado | Detalle |
|---|---|---|
| 5 instancias con coordenadas correctas (espacio local shapefile) | ✅ **Listo** | C1–C5 posicionados en accesos del polígono |
| `modo_peaje_activo = false` en E0 | ✅ **Listo** | Controles visualmente verdes, tarifa siempre 0.0 |
| `reflex cobrar` en EB (tarifa_base por franja horaria) | ✅ **Listo** | `tarifa_base` actualizado automáticamente según `es_hora_pico` |
| Cobro $0 en fines de semana | ✅ **Listo** | `reflex cobrar_fin_semana` implementado |
| Visualización de tarifa vigente ($X.XX) en el mapa | ✅ **Listo** | `draw "$" + tarifa_vigente` en aspecto 3D |
| **Exoneración por tipo de vehículo** (buses, emergencias) | ❌ **Falta** | El código no diferencia vehículos exonerados del peaje por categoría |

### 1.4 Species `EstacionMetro`

| Componente | Estado | Detalle |
|---|---|---|
| 2 estaciones posicionadas en el polígono | ✅ **Listo** | Coordenadas en espacio local del shapefile |
| Capacidad de absorción (`capacidad_hora = 8000`) | ✅ **Listo** | Flag `saturada` se activa al 90 % |
| Salida de trenes cada 5 min sim (`cycle mod 30`) | ✅ **Listo** | Libera hasta 300 pasajeros por ciclo |
| Acumulador `modal_shift_total` | ✅ **Listo** | Suma total de pasajeros abordados en toda la simulación |
| **Nombre de estación norte** | ⚠️ **Inconsistencia** | El código usa `"La Carolina"` pero `SMA.md §7.1` especifica `"El Labrador"` como estación norte real |

### 1.5 Species `GestorAMT` (solo en EB)

| Componente | Estado | Detalle |
|---|---|---|
| Creencias: densidad, velocidad, tendencia, saturación Metro | ✅ **Listo** | `reflex actualizar_creencias` cada ciclo |
| Deliberación BDI: 5 reglas (MANTENER / SUBIR / BAJAR / SUSPENDER) | ✅ **Listo** | Cada 30 ciclos = 5 min simulados |
| Comunicación FIPA: `ask PuntoControl` para difundir nueva tarifa | ✅ **Listo** | Patrón facilitador implementado |
| Límites de tarifa ($0.50 mínimo pico / $3.00 máximo) | ✅ **Listo** | `TARIFA_MIN_PICO`, `TARIFA_MAX`, `PASO_AJUSTE = $0.25` |
| Flag `GESTOR_ACTIVO` para comparar tarifa fija vs. dinámica | ✅ **Listo** | Útil para análisis de sensibilidad |
| **Display dedicado "GestorAMT — Estado"** | ❌ **Falta** | `aspect default { }` está vacío; no hay display separado del gestor en el experimento |

---

## 2. DATOS GEOESPACIALES Y CALIBRACIÓN

| Componente | Estado | Detalle |
|---|---|---|
| Shapefile red vial La Carolina (`.shp`, `.dbf`, `.shx`, `.prj`, `.cpg`) | ✅ **Listo** | Todos los archivos componentes presentes |
| Sistema de referencia EPSG:32717 (UTM 17S) | ✅ **Listo** | Especificado en `.prj` |
| 5 puntos de control con coordenadas en espacio local | ✅ **Listo** | Calibradas al BBOX del shapefile (0–3790 × 0–4210) |
| Parámetros NSE calibrados con datos AMT | ✅ **Listo** | Reflejados como constantes globales en ambos modelos GAML |
| Iconos de vehículos (`voit.png`, `voit_blue.png`, `voit_red.png`) | ✅ **Listo** | Presentes en `includes/` (no están siendo usados en los aspectos actuales) |
| **CSV de parámetros BDI por perfil NSE** (entregable P2) | ❌ **Falta** | Solo existen como parámetros hardcoded en el GAML, no como documento independiente |
| **Tabla de calibración formal** (flujo vehicular AMT vs. modelo) | ❌ **Falta** | No existe comparación documentada entre flujos reales AMT y los producidos por E0 |
| **Polígono de cobro como capa GIS separada** | ❌ **Falta** | Solo existe como 5 puntos discretos de control; no hay geometría de área para el paper |

---

## 3. OBSERVACIONES TÉCNICAS Y PENDIENTES

### 3.0 ✅ Fixes aplicados en EB_PeajeHorario.gaml (v2 — junio 2026)

| Fix | Problema original | Solución aplicada |
|-----|-------------------|-------------------|
| FIX-1 | `ask (EstacionMetro closest_to self)` explota con `nil agent` cuando EstacionMetro está vacío | Añadida guardia `if not empty(EstacionMetro)` antes de cada `ask closest_to` en `action decidir` |
| FIX-2 | `reflex cobrar` del PuntoControl sobreescribía `tarifa_vigente` cada ciclo, anulando los ajustes del GestorAMT | El `reflex cobrar` solo actúa cuando `GESTOR_ACTIVO = false`; fuera de hora pico fuerza 0.0; el gestor escribe directamente vía `ask` |
| FIX-3 | Con 150 conductores la densidad no superaba `umbral_congestion` → 0% deliberación BDI | `NB_CONDUCTORES` default subido a 300 (rango slider 50–500 sigue disponible) |
| FIX-4 | Agentes cerca de puntos de control en hora pico no deliberaban si no había suficiente congestión local | `reflex deliberar` añade trigger periódico `(es_hora_pico and PEAJE_ACTIVO and (cycle mod 60 = 0))` |
| FIX-5 | Encabezado CSV duplicado en EB_run1_metricas.csv | Flag `csv_header_escrito` idéntico al E0; encabezado solo en `init` con `rewrite: true` |
| FIX-6 | Estación norte nombrada `"La Carolina"` en vez de `"El Labrador"` (SMA.md §7.1) | Corregido a `"El Labrador"`; posición ajustada a `{1800.0, 3700.0}` |

---

### 3.1 🟡 E0 — Deliberación BDI condicionada al número de agentes

**Observación (basada en el código):** El `reflex deliberar` en `ConductorBDI` se activa únicamente cuando se cumple al menos una de estas condiciones:

```gaml
reflex deliberar when: not decision_tomada
                   and (tarifa_percibida > 0 or nivel_congestion >= umbral_congestion)
```

- En E0, `tarifa_percibida` siempre es 0.0 → el primer trigger no aplica.
- El segundo trigger depende de que `nivel_congestion >= umbral_congestion`. Este nivel se calcula como la fracción de vías cercanas con `speed_coeff ≤ 0.5`, lo que a su vez depende de cuántos agentes ocupan cada vía simultáneamente.

**Lo que muestran los datos actuales (CSV `E0_run1_metricas.csv`):** Con el valor actual de `NB_CONDUCTORES = 150` la densidad en la red no es suficiente para superar el umbral de congestión, y los agentes no deliberan. El resultado observado es 100 % `pct_ruta_directa` con 0 decisiones en las otras categorías.

> **Recomendación antes de sacar conclusiones:** Realizar pruebas incrementales de densidad usando el slider de `NB_CONDUCTORES` en el experimento (rango 50–500 disponible en tiempo real) hasta encontrar el valor mínimo que produce deliberación BDI visible. Documentar ese umbral como parámetro de calibración del modelo.

### 3.2 🟡 EB — Simulación incompleta en el CSV disponible

**Observación:** El CSV `EB_run1_metricas.csv` contiene registros desde las 06:15 h hasta las 09:15 h solamente (minuto 375 al 555). El modelo está programado para terminar a las 22:00 h (minuto 1320) mediante `reflex fin_sim`, por lo que la ejecución se interrumpió externamente antes del fin del día simulado.

**Lo que sí funciona según el CSV disponible:** En el intervalo capturado (franja pico matutina 07:00–09:15 h) el modelo EB sí produce deliberación BDI activa: distribuciones del orden de 39–42 % ruta directa, 18–22 % rerouteo y 39–43 % Metro, con recaudación acumulándose correctamente.

> **Recomendación:** Ejecutar la simulación EB completa (06:00–22:00 h) sin interrupciones y capturar los datos de la franja vespertina (17:00–20:00 h). Solo con ambas franjas pico es posible hacer una comparación completa E0 vs EB y calcular las métricas del paper.

### 3.3 🟡 EB — Encabezado duplicado en el CSV de salida

**Observación (basada en el archivo):** El archivo `EB_run1_metricas.csv` tiene las primeras dos líneas con encabezado: la primera con comillas simples (`'escenario','minuto',...`) y la segunda sin ellas (`escenario,minuto,...`). El script `01_process_results.py` usa `skiprows=1`, que solo omite una de las dos filas.

**Impacto:** La segunda línea de encabezado queda como un registro de datos con valores no numéricos, lo que produce errores silenciosos en la limpieza del DataFrame. Los datos de la fila EB de las 06:15 h se pierden o generan NaN.

> **Recomendación:** Revisar el bloque `init` de `EB_PeajeHorario.gaml` para asegurar que el encabezado CSV se escriba una sola vez (el modelo E0 no presenta este problema). Alternativamente, ajustar `01_process_results.py` a `skiprows=2` como solución temporal para el EB.

### 3.4 🟡 Inconsistencia — Nombre de estación Metro norte

**Observación:** El código GAML crea la estación norte con `nombre::"La Carolina"`, mientras que `SMA.md §7.1` especifica `"El Labrador"` como la estación norte del polígono de cobro.

**Impacto:** Bajo en la simulación, pero afecta la validez científica del paper porque la estación real que sirve al norte del polígono es El Labrador, no La Carolina.

> **Recomendación:** Actualizar `nombre::"La Carolina"` → `nombre::"El Labrador"` en el `init` de ambos modelos GAML para alinear el código con los datos geográficos reales.

### 3.5 🟢 Iconos de vehículo disponibles sin usar

**Observación:** Los archivos `voit.png`, `voit_blue.png`, `voit_red.png` están presentes en `gama/includes/` pero el `aspect default` del `ConductorBDI` dibuja `circle(20)`. Los iconos no están referenciados en ningún modelo GAML.

> **Recomendación (opcional):** Usar `draw image(...)` con los iconos en el aspecto del agente para mejorar la legibilidad visual del mapa. Puede diferenciarse el icono por intención activa (azul = ruta directa, naranja = rerouteo, verde = Metro).

### 3.6 🔵 Mejora pendiente — Diferenciación por tipo de vehículo

**Observación (basada en el código):** El modelo actual define un único `species ConductorBDI` que representa indistintamente cualquier vehículo de la flota. Todos los agentes comparten la misma lógica de movimiento (`speed` en rango 30–110 m/ciclo), la misma función de utilidad y la misma interacción con los puntos de control.

**Qué falta implementar:** El modelo no diferencia entre:

| Tipo | Impacto en la política | Diferencia modelable |
|---|---|---|
| **Moto** | Tarifa reducida o exonerada en la propuesta DMQ; mayor movilidad en tráfico denso | Speed mayor, `capacity` por vía diferente, WTP más bajo, exoneración de peaje |
| **Auto particular** | Agente central actual (NSE diferenciado) | Ya modelado — es el tipo base actual |
| **Auto grande / SUV** | Mayor ocupación de vía (`capacity` reducida) | Peso mayor en `nb_people` por vía, WTP potencialmente más alto |
| **Bus / Transporte público** | Exonerado del peaje en todos los escenarios (SMA.md §7.2) | Sin cobro en PuntoControl; velocidad más baja; no puede "ir al Metro" |
| **Vehículo de carga** | Posible restricción horaria adicional al peaje; mayor impacto en velocidad de vías | Restricción por horario, peso alto en congestión de vía |

**Por qué importa para el paper:** La exoneración de buses ya está mencionada en `SMA.md §7.2` pero no está implementada en el código. La distribución de tipos vehiculares afecta directamente la recaudación estimada, el índice de equidad (Δ Gini modal) y la reducción vehicular neta — métricas clave del benchmark contra Londres.

> **Recomendación de implementación:** Añadir un atributo `tipo_vehiculo` al `ConductorBDI` con valores `"MOTO"`, `"AUTO"`, `"SUV"`, `"BUS"`, `"CARGA"`. Ajustar la lógica del `PuntoControl` para exonerar a buses y motos según la política propuesta. Calibrar la distribución de tipos con datos del parque automotor DMQ (INEC 2023: ~600 000 vehículos, distribución por categoría disponible en el Anuario de Transporte).

---

## 4. PIPELINE DE ANÁLISIS PYTHON

| Script | Estado | Detalle |
|---|---|---|
| `01_process_results.py` — carga y limpieza de CSVs | ✅ **Listo** | Maneja múltiples réplicas; genera datos sintéticos si no hay CSVs reales |
| `02_compare_scenarios.py` — tablas comparativas + benchmark Londres | ✅ **Listo** | Test t de Student, veredicto de hipótesis, output LaTeX directo |
| `03_generate_figures.py` — 5 figuras PNG/PDF 300 DPI | ✅ **Listo** | Fig1–Fig5 con estilo de paper IEEE, listas para Overleaf |
| Datos sintéticos de prueba para el pipeline | ✅ **Listo** | `generar_datos_ejemplo()` produce datos realistas para probar sin GAMA |
| **Lectura del CSV EB con encabezado doble** | ❌ **Falta** | `skiprows=1` en `01_process_results.py` no corrige el doble encabezado del EB |
| **Figura de equidad por NSE** (Δ Gini modal) | ❌ **Falta** | Los datos `directo_nse_*`, `metro_nse_*`, `rerouta_nse_*` se exportan en el CSV pero no se grafican |
| **Figura de recaudación acumulada** (EB) | ❌ **Falta** | Columna `recaudacion_acum_usd` disponible en el CSV EB, sin figura dedicada |
| **Figura de tarifa dinámica del GestorAMT** | ❌ **Falta** | No hay visualización de cómo el gestor ajusta `tarifa_vigente` a lo largo del día |
| **Análisis por tipo de vehículo** | ❌ **Falta** | No implementable hasta que se diferencien tipos en el modelo GAML |

---

## 5. DOCUMENTACIÓN Y PAPER ACADÉMICO

| Componente | Estado | Detalle |
|---|---|---|
| Documento de proyecto `docs/SMA.md` | ✅ **Listo** | 15 secciones: contexto, hipótesis, diseño, roadmap, referencias |
| `README.md` profesional para GitHub | ✅ **Listo** | Badges, estructura, inicio rápido, tabla de agentes |
| `.gitignore` y `requirements.txt` | ✅ **Listo** | Dependencias Python fijadas con versiones exactas |
| `LICENSE` MIT | ✅ **Listo** | Incluye atribución a OpenStreetMap |
| **Plantilla LaTeX en Overleaf** | ❌ **Falta** | No creada aún (entregable P5, semana 1–2 del roadmap) |
| **Sección de Metodología del paper** | ❌ **Falta** | Puede redactarse ya, basándose en el código existente |
| **Tablas de resultados** | ❌ **Falta** | Requieren simulaciones completas E0 y EB con deliberación activa |
| **Figuras del paper** (Fig1–Fig5) | ⚠️ **Parcialmente listo** | Scripts listos; requieren CSVs completos y válidos para producir figuras reales |
| **Sección de Discusión** (benchmark Londres) | ❌ **Falta** | Requiere resultados finales del modelo |

---

## 6. TAREAS PENDIENTES POR PRIORIDAD

### 🔴 Prioridad ALTA — Necesarias para tener datos válidos para el paper

1. **Probar E0 con distintos valores de `NB_CONDUCTORES`** usando el slider del experimento (rango 50–500) hasta que la deliberación BDI sea observable en el CSV. Documentar el valor que produce un comportamiento representativo.
2. **Ejecutar E0 completo** (06:00–22:00 h) con el número de conductores calibrado y verificar que `pct_reroutean` y `pct_metro` sean mayores a 0 % en al menos las franjas pico.
3. **Ejecutar EB completo** (06:00–22:00 h) sin interrupciones, capturando tanto la franja pico matutina como la vespertina.
4. **Corregir el encabezado doble del CSV EB** (en el modelo GAML o en `01_process_results.py`) para que el pipeline de análisis lo procese sin errores.

### 🟡 Prioridad MEDIA — Mejoran validez y presentación

5. **Corregir nombre de estación**: `"La Carolina"` → `"El Labrador"` en el `init` de ambos modelos GAML.
6. **Ejecutar el pipeline Python** con los CSVs reales y verificar que las 5 figuras se generen correctamente con datos de simulación (no sintéticos).
7. **Implementar diferenciación por tipo de vehículo** (moto, auto, SUV, bus, carga) en `ConductorBDI` y exoneración en `PuntoControl`. Ver sección 3.6.
8. **Añadir figura de equidad NSE** (`fig6_equidad_nse`) en `03_generate_figures.py` usando los contadores por NSE ya disponibles en los CSVs.
9. **Añadir figura de recaudación y tarifa dinámica** (`fig7_recaudacion`, `fig8_tarifa_gestor`) en `03_generate_figures.py`.
10. **Crear la plantilla LaTeX en Overleaf** (IEEE Conference Proceedings) con la estructura de 6 secciones de `SMA.md §15`.

### 🟢 Prioridad BAJA — Mejoras opcionales de calidad

11. **Usar iconos de vehículo** (`voit_blue.png`, `voit_red.png`) en el `aspect default` de `ConductorBDI`.
12. **Añadir display del GestorAMT** en el experimento EB con su estado en tiempo real (densidad, velocidad, intención, tarifa gestionada).
13. **Exportar CSV de parámetros BDI** como archivo independiente documentado (entregable formal P2).
14. **Redactar tabla de calibración formal** comparando flujos reales AMT con los del E0 calibrado.

---

## 7. MAPA DE DEPENDENCIAS PARA EL PAPER

```
Pruebas de densidad E0 (tarea 1)
    └─→ Ejecutar E0 completo calibrado (tarea 2)
            └─→ Pipeline Python con datos reales (tarea 6)
                    └─→ Figuras Fig1–Fig5 reales
                            └─→ Sección Resultados del paper

Ejecutar EB completo (tarea 3)
    └─→ Corregir encabezado CSV EB (tarea 4)
            └─→ Pipeline Python con datos reales (tarea 6)

Diferenciación por tipo de vehículo (tarea 7)  ←── mejora el análisis de equidad
    └─→ Nuevas figuras NSE + recaudación (tareas 8–9)
            └─→ Sección Discusión más robusta

Plantilla Overleaf (tarea 10) ←── puede hacerse en paralelo desde ya
    └─→ Metodología (se puede escribir ya, basada en el código)
            └─→ Resultados (después de tareas 1–6)
                    └─→ Discusión (benchmark Londres)
                            └─→ Paper completo
```

---

## 8. ESTADO POR PERSONA DEL EQUIPO

| Persona | Rol | Estado actual | Tarea inmediata |
|---------|-----|---------------|-----------------|
| P1 | Geoespacial | ✅ Shapefile entregado y funcionando en GAMA | Crear polígono de cobro como capa GIS de área para el paper |
| P2 | Datos y calibración | ⚠️ Parámetros en el código, no documentados formalmente | Exportar CSV de parámetros BDI; redactar tabla de calibración con datos AMT |
| P3 | GAML (principal) | ⚠️ Lógica BDI completa; deliberación requiere pruebas de densidad | Probar `NB_CONDUCTORES` en slider y documentar valor de calibración; implementar tipos de vehículo |
| P4 | GAML (soporte) | ⚠️ EB produce resultados correctos en franja disponible; CSV incompleto y con encabezado doble | Corregir encabezado CSV; ejecutar EB completa (06:00–22:00 h) |
| P5 | Paper y análisis | ⚠️ Pipeline Python listo con datos sintéticos; Overleaf pendiente | Crear plantilla LaTeX; redactar sección de Metodología con el código actual como base |

---

*Documento actualizado el 7 de junio de 2026 — análisis basado en revisión directa del código fuente y datos del repositorio `sma_quito`.*
