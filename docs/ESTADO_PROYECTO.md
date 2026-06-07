# Estado del Proyecto — SMA Movilidad Urbana Quito
## Auditoría técnica: qué está listo y qué falta

> **Fecha de revisión:** Junio 2026  
> **Basado en:** `docs/SMA.md`, código GAML en `gama/models/`, scripts Python en `analysis/scripts/`, datos en `gama/outputs/`

---

## Resumen ejecutivo

El proyecto tiene una base sólida: la arquitectura BDI está implementada, la red vial está integrada y el pipeline de análisis Python está completo. Sin embargo, existen **dos problemas críticos** que impiden obtener resultados válidos para el paper:

1. **El Escenario E0 (baseline) no produce decisiones BDI** — todos los agentes reportan 100 % `RUTA_DIRECTA` durante toda la simulación. La deliberación nunca se activa porque el umbral de congestión no se alcanza con 150 agentes en la red real.
2. **El Escenario EB termina abruptamente** — el CSV solo tiene datos hasta las 9:15 h (franja pico matutina) y no cubre el día completo ni la franja vespertina.

Sin corregir estos dos puntos, la comparación E0 vs EB no es válida y el paper no tiene sustento empírico.

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
| Parámetros interactivos en el experimento | ✅ **Listo** | Sliders de conductores, día semana, tarifa pico |

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
| **Trigger de deliberación en E0** | ❌ **Bug crítico** | Ver sección 3.1 — la deliberación nunca se activa en la práctica |

### 1.3 Species `PuntoControl`

| Componente | Estado | Detalle |
|---|---|---|
| 5 instancias con coordenadas correctas (espacio local shapefile) | ✅ **Listo** | C1–C5 posicionados en accesos del polígono |
| `modo_peaje_activo = false` en E0 | ✅ **Listo** | Controles visualmente verdes, tarifa siempre 0.0 |
| `reflex cobrar` en EB (tarifa_base por franja horaria) | ✅ **Listo** | `tarifa_base` actualizado automáticamente según `es_hora_pico` |
| Cobro $0 en fines de semana | ✅ **Listo** | `reflex cobrar_fin_semana` implementado |
| Visualización de tarifa vigente ($X.XX) en el mapa | ✅ **Listo** | `draw "$" + tarifa_vigente` en aspecto 3D |

### 1.4 Species `EstacionMetro`

| Componente | Estado | Detalle |
|---|---|---|
| 2 estaciones (Iñaquito, La Carolina) | ✅ **Listo** | Posicionadas en el polígono |
| Capacidad de absorción (`capacidad_hora = 8000`) | ✅ **Listo** | Flag `saturada` se activa al 90 % |
| Salida de trenes cada 5 min sim (`cycle mod 30`) | ✅ **Listo** | Libera hasta 300 pasajeros por ciclo |
| Acumulador `modal_shift_total` | ✅ **Listo** | Suma total de pasajeros abordados en toda la simulación |
| **Nombre de estación** | ⚠️ **Inconsistencia** | El modelo usa "La Carolina" pero la documentación dice "El Labrador" |

### 1.5 Species `GestorAMT` (solo en EB)

| Componente | Estado | Detalle |
|---|---|---|
| Creencias: densidad, velocidad, tendencia, saturación Metro | ✅ **Listo** | `reflex actualizar_creencias` cada ciclo |
| Deliberación BDI: 5 reglas de decisión (MANTENER/SUBIR/BAJAR/SUSPENDER) | ✅ **Listo** | Cada 30 ciclos = 5 min simulados |
| Comunicación FIPA: `ask PuntoControl` para difundir nueva tarifa | ✅ **Listo** | Patrón facilitador implementado |
| Límites de tarifa ($0.50 mínimo pico / $3.00 máximo) | ✅ **Listo** | `TARIFA_MIN_PICO`, `TARIFA_MAX`, `PASO_AJUSTE = $0.25` |
| Flag `GESTOR_ACTIVO` para comparar tarifa fija vs. dinámica | ✅ **Listo** | Útil para el análisis de sensibilidad del paper |
| **Display dedicado "GestorAMT — Estado"** | ❌ **Falta** | El aspecto está vacío (`aspect default { }`); no hay display separado del gestor |

---

## 2. DATOS GEOESPACIALES Y CALIBRACIÓN

| Componente | Estado | Detalle |
|---|---|---|
| Shapefile red vial La Carolina (`.shp`, `.dbf`, `.shx`, `.prj`, `.cpg`) | ✅ **Listo** | Todos los archivos componentes del shapefile presentes |
| Sistema de referencia EPSG:32717 (UTM 17S) | ✅ **Listo** | Especificado en `.prj` |
| 5 puntos de control con coordenadas en espacio local | ✅ **Listo** | Calibradas al BBOX del shapefile (0–3790 × 0–4210) |
| Parámetros NSE calibrados con datos AMT | ✅ **Listo** | Reflejados en los parámetros globales de GAMA |
| **CSV de parámetros BDI por perfil NSE** (entregable P2) | ❌ **Falta** | Solo existe como parámetros hardcoded en el GAML, no como CSV documentado separado |
| **Tabla de calibración formal** (flujo vehicular AMT vs. modelo) | ❌ **Falta** | No hay documento que compare flujos reales AMT con los del E0 |
| **Polígono de cobro como capa GIS separada** | ❌ **Falta** | El polígono solo existe como 5 puntos discretos, no como geometría de área |
| Iconos de vehículos (`voit.png`, `voit_blue.png`, `voit_red.png`) | ✅ **Listo** | Presentes en `includes/` (no están siendo usados en los aspectos actuales) |

---

## 3. BUGS Y PROBLEMAS CRÍTICOS

### 3.1 🔴 Bug crítico — E0: deliberación BDI nunca se activa

**Síntoma:** El CSV `E0_run1_metricas.csv` muestra 100 % `pct_ruta_directa` y 0 % en `pct_reroutean` y `pct_metro` durante **toda** la simulación (06:15–14:30 h y más allá).

**Causa raíz:** El trigger de `reflex deliberar` tiene dos condiciones:
```gaml
reflex deliberar when: not decision_tomada
                   and (tarifa_percibida > 0 or nivel_congestion >= umbral_congestion)
```
- En E0, `tarifa_percibida` siempre es 0.0 (sin peaje) → primer trigger inactivo.
- Con solo 150 agentes en una red vial completa, la densidad en cada vía es muy baja → `speed_coeff` no cae a ≤ 0.5 → `nivel_congestion` se mantiene cerca de 0.0 → segundo trigger inactivo.

**Consecuencia:** Los agentes no deliberan nunca. El 100 % elige `RUTA_DIRECTA` sin evaluar ninguna alternativa. Los contadores por NSE son todos 0. **El E0 no representa un estado de tráfico realista.**

**Solución propuesta:** Aumentar el número de conductores (`NB_CONDUCTORES`) a 300–500, o ajustar los umbrales de congestión a valores más bajos (ej. `umbral_congestion` NSE MEDIO: 0.25). También se puede forzar un porcentaje mínimo de deliberación periódica sin depender de la congestión.

### 3.2 🔴 Bug crítico — EB: simulación termina antes del fin del día

**Síntoma:** El CSV `EB_run1_metricas.csv` solo tiene registros hasta las 9:15 h (minuto 555). La franja pico vespertina (17:00–20:00 h) y las horas intermedias no están capturadas.

**Causa probable:** La simulación se detuvo manualmente o crasheó. El `reflex fin_sim` está configurado para las 22:00 h (minuto 1320), por lo que la parada fue externa o hubo un error de ejecución no registrado.

**Consecuencia:** Solo hay ~45 minutos de datos de la franja pico matutina. No hay datos de la franja vespertina. **La comparación E0 vs EB no puede hacerse con el rango temporal completo.**

**Solución:** Ejecutar ambas simulaciones completas desde las 06:00 h hasta las 22:00 h sin interrupciones. Verificar que no haya errores de memoria con 150 conductores durante ~5600 ciclos.

### 3.3 🟡 Problema menor — EB: encabezado duplicado en el CSV

**Síntoma:** El archivo `EB_run1_metricas.csv` tiene el encabezado escrito **dos veces** (una con comillas simples y otra sin ellas) en las primeras dos líneas, lo que rompe la lectura con `pandas`.

**Causa:** En el `init` del modelo EB, el CSV se escribe con `rewrite: true` pero la lógica del modelo también lo escribe una segunda vez. El script `01_process_results.py` usa `skiprows=1`, que salta solo una fila y deja la segunda línea de encabezado como un registro de datos inválido.

**Solución:** Revisar el `init` de `EB_PeajeHorario.gaml` para garantizar una sola escritura del encabezado (igual al E0 que funciona correctamente).

### 3.4 🟡 Inconsistencia de datos — Nombre de estación Metro

**Síntoma:** Los modelos GAML crean la estación `"La Carolina"` pero la documentación `SMA.md` especifica `"El Labrador"` como la estación norte del polígono.

**Impacto:** Bajo en la simulación (solo afecta el nombre visible en el display), pero alto para la validez científica del paper, ya que la estación real es El Labrador.

**Solución:** Cambiar `nombre::"La Carolina"` a `nombre::"El Labrador"` en el `init` de ambos modelos GAML.

### 3.5 🟡 Recursos sin usar — Iconos de vehículos

**Síntoma:** Los archivos `voit.png`, `voit_blue.png`, `voit_red.png` están en `includes/` pero los agentes `ConductorBDI` usan `draw circle(20)` en lugar de los iconos.

**Impacto:** Ninguno funcional, pero el aspecto visual del mapa sería más realista y profesional con iconos de vehículos.

---

## 4. PIPELINE DE ANÁLISIS PYTHON

| Script | Estado | Detalle |
|---|---|---|
| `01_process_results.py` — carga y limpieza de CSVs | ✅ **Listo** | Maneja múltiples réplicas, genera datos sintéticos si no hay CSVs reales |
| `02_compare_scenarios.py` — tablas comparativas + benchmark Londres | ✅ **Listo** | Test t de Student, veredicto de hipótesis, output LaTeX |
| `03_generate_figures.py` — 5 figuras PNG/PDF 300 DPI | ✅ **Listo** | Fig1–Fig5 con estilo de paper IEEE |
| Datos sintéticos de prueba para el pipeline | ✅ **Listo** | `generar_datos_ejemplo()` produce datos realistas para probar sin GAMA |
| **Lectura correcta del CSV EB** (bug encabezado doble) | ❌ **Falta** | `skiprows=1` no compensa el doble encabezado del EB |
| **Figura de equidad por NSE** (Δ Gini modal) | ❌ **Falta** | Los datos por NSE se exportan en el CSV pero no se grafican |
| **Figura de recaudación acumulada** (EB únicamente) | ❌ **Falta** | Los datos existen en el CSV EB pero no hay figura dedicada |
| **Figura del GestorAMT** (tarifa dinámica en el tiempo) | ❌ **Falta** | No hay visualización de cómo el gestor ajusta tarifas a lo largo del día |

---

## 5. DOCUMENTACIÓN Y PAPER ACADÉMICO

| Componente | Estado | Detalle |
|---|---|---|
| Documento de proyecto `docs/SMA.md` | ✅ **Listo** | 15 secciones completas: contexto, hipótesis, diseño, roadmap, referencias |
| `README.md` profesional para GitHub | ✅ **Listo** | Badges, estructura, inicio rápido, tabla de agentes |
| `.gitignore` y `requirements.txt` | ✅ **Listo** | Dependencias Python fijadas con versiones exactas |
| `LICENSE` MIT | ✅ **Listo** | Incluye atribución a OpenStreetMap |
| **Estructura del paper en Overleaf** | ❌ **Falta** | No se ha creado aún la plantilla LaTeX en Overleaf (entregable P5, semana 1–2) |
| **Sección de Metodología del paper** | ❌ **Falta** | Debe redactarse en paralelo con los sprints S1–S2 (semanas 5–6) |
| **Tablas de resultados** (del paper) | ❌ **Falta** | Requieren simulaciones completas E0 y EB sin bugs |
| **Figuras del paper** (Fig1–Fig5) | ⚠️ **Parcialmente listo** | Los scripts están listos, pero dependen de CSVs completos y válidos |
| **Sección de Discusión** (benchmark Londres) | ❌ **Falta** | Requiere resultados finales del modelo para comparar |

---

## 6. RESUMEN DE TAREAS PENDIENTES POR PRIORIDAD

### 🔴 Prioridad ALTA — Bloquean el paper

1. **Corregir bug E0**: aumentar `NB_CONDUCTORES` a 300–500 o bajar umbrales de congestión para que la deliberación BDI se active en el baseline.
2. **Ejecutar simulación E0 completa** (06:00–22:00 h) y verificar que los CSVs tengan datos en todas las franjas horarias y que los porcentajes de deliberación sean distintos de 100 % / 0 % / 0 %.
3. **Ejecutar simulación EB completa** (06:00–22:00 h) sin interrupciones, capturando la franja pico vespertina (17:00–20:00 h).
4. **Corregir encabezado doble del CSV EB** para que `01_process_results.py` lo lea correctamente.

### 🟡 Prioridad MEDIA — Mejoran la validez y presentación

5. **Corregir nombre de estación**: cambiar `"La Carolina"` → `"El Labrador"` en ambos modelos GAML.
6. **Ejecutar el pipeline de análisis** con los CSVs reales (no sintéticos) y verificar que Fig1–Fig5 se generen correctamente.
7. **Añadir figura de equidad NSE** en `03_generate_figures.py` usando los contadores `directo_nse_*`, `metro_nse_*`, `rerouta_nse_*` que ya están en el CSV.
8. **Añadir figura de recaudación acumulada** y figura de evolución de la tarifa dinámica del `GestorAMT`.
9. **Crear la plantilla LaTeX en Overleaf** (IEEE Conference Proceedings) con la estructura de 6 secciones definida en `SMA.md §15`.

### 🟢 Prioridad BAJA — Mejoras opcionales

10. **Usar iconos de vehículo** (`voit_blue.png`, `voit_red.png`) en el `aspect default` del `ConductorBDI` para mejorar la visualización.
11. **Añadir display del GestorAMT** en el experimento de EB con su estado (densidad, velocidad, intención, tarifa gestionada).
12. **Crear el CSV de parámetros BDI** como archivo independiente documentado (entregable formal de P2).
13. **Redactar tabla de calibración formal** comparando flujos reales AMT (datos §6.1 del SMA.md) con los del Escenario E0 final.
14. **Ajustar `01_process_results.py`** para manejar el `skiprows` correcto del CSV EB con encabezado doble.

---

## 7. MAPA DE DEPENDENCIAS PARA EL PAPER

```
Corregir bug E0 (tarea 1)
    └─→ Ejecutar E0 completo (tarea 2)
            └─→ Pipeline Python con datos reales (tarea 6)
                    └─→ Figuras válidas Fig1–Fig5 (tarea 6)
                            └─→ Sección de Resultados del paper

Ejecutar EB completa (tarea 3)
    └─→ Corregir encabezado CSV EB (tarea 4)
            └─→ Pipeline Python con datos reales (tarea 6)

Plantilla Overleaf (tarea 9) ←── puede hacerse en paralelo con todo lo demás
    └─→ Sección Metodología (escribir mientras se corrigen bugs)
            └─→ Resultados (después de tareas 1–6)
                    └─→ Discusión (benchmark Londres)
                            └─→ Paper completo
```

---

## 8. ESTADO POR PERSONA DEL EQUIPO

| Persona | Rol | Estado actual | Tarea inmediata |
|---------|-----|---------------|-----------------|
| P1 | Geoespacial | ✅ Shapefile entregado y funcionando | Crear polígono de cobro como capa GIS separada para el paper |
| P2 | Datos y calibración | ⚠️ Parámetros en el código, no documentados formalmente | Exportar CSV de parámetros BDI y redactar tabla de calibración |
| P3 | GAML (principal) | ⚠️ Lógica BDI completa pero con bug de deliberación en E0 | **Tarea crítica**: corregir el umbral de congestión para activar la deliberación |
| P4 | GAML (soporte) | ⚠️ EB funciona pero incompleto; encabezado CSV duplicado | Ejecutar EB completo y corregir bug de encabezado |
| P5 | Paper y análisis | ⚠️ Pipeline Python listo, Overleaf pendiente | **Tarea urgente**: crear plantilla LaTeX y empezar sección de Metodología |

---

*Documento generado el 7 de junio de 2026 — revisión de código y datos del repositorio `sma_quito`.*
