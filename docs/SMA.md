# Simulación Multiagente del Impacto de una Zona de Cobro por Congestión — Parque La Carolina

**BDI-based Multi-Agent Simulation of Congestion Pricing around Parque La Carolina:
A Policy Evaluation Tool for Quito's Urban Mobility**

> Documento de especificación del proyecto y fuente de verdad para parámetros e hipótesis.
> El código cita este archivo por sección (p. ej. `SMA.md §7.2`); **no renumerar las secciones.**

| | |
|---|---|
| **Asignatura** | Sistemas Colaborativos (TGP09BFT03) — Noveno Semestre |
| **Unidades** | U3 (Sistemas Multiagentes) · U4 (Simulación y Modelamiento SMA) |
| **Docente** | Luis Felipe Borja |
| **Período** | 2026 |
| **Herramientas** | GAMA Platform 2.0 · GAML · QGIS 3.x · Overleaf (LaTeX) · Python |
| **Equipo** | 5 integrantes — Carrera de Computación, FICA, Universidad Central del Ecuador |

---

## 2. Planteamiento del Problema

### 2.1 Contexto y motivación

El Distrito Metropolitano de Quito (DMQ) registra más de **600 000 vehículos** en circulación
(INEC, Anuario de Transporte 2023), con un crecimiento del parque automotor que supera la
capacidad de expansión vial. El sector del **Parque La Carolina** concentra los corredores de
mayor congestión del norte —Naciones Unidas, Amazonas, De los Shyris, Eloy Alfaro y 6 de
Diciembre—, una zona comercial y financiera sin ningún mecanismo de gestión de demanda.

El Municipio del DMQ incluyó en el Plan Maestro de Movilidad la propuesta conceptual de una
zona de cobro por congestión en La Carolina, pero **no existe análisis cuantitativo publicado**
que evalúe su viabilidad considerando el comportamiento heterogéneo de los usuarios, el Metro de
Quito (operativo desde dic. 2023) y la restricción preexistente de "tercera placa". El Modelado
Basado en Agentes (ABM) es idóneo para este vacío: representa la heterogeneidad individual,
modela la emergencia del desplazamiento de tráfico y permite evaluar el impacto por nivel
socioeconómico.

### 2.2 Pregunta de investigación

> ¿Es la zona de cobro por congestión en La Carolina una política viable para reducir el tráfico
> vehicular en Quito, considerando el comportamiento heterogéneo de los usuarios, la oferta del
> Metro de Quito y el efecto de la tercera placa?

### 2.3 Hipótesis principal

> La zona de cobro con tarifa dinámica BDI en el polígono La Carolina **reduce el volumen
> vehicular de paso en al menos un 20 %**, incrementa el uso del Metro y no genera un
> desplazamiento crítico hacia vías periféricas, frente al escenario sin peaje.

El umbral del 20 % se establece tomando como referencia el **−27 %** del *London Congestion
Charge* en sus primeros seis meses (2003).

---

## 3. Objetivos

### 3.1 Objetivo general

Desarrollar un SMA con arquitectura **BDI** e integración de datos geoespaciales reales que
simule y evalúe el impacto de una zona de cobro por congestión en La Carolina, comparando un
baseline sin peaje contra un peaje por franja horaria, y documentar los resultados en un paper
académico (IEEE).

### 3.2 Objetivos específicos

| # | Objetivo específico |
|---|---|
| **OE1** | Modelar el polígono con datos GIS reales (red OSM, puntos de control, estaciones Metro, densidad INEC) en formato GAMA. |
| **OE2** | Implementar agentes-vehículo BDI con función de utilidad diferenciada por perfil socioeconómico y tres decisiones: pagar / reroutear / Metro. |
| **OE3** | Integrar la tercera placa como restricción preexistente, calibrando con datos de la AMT. |
| **OE4** | Ejecutar y comparar **E0 (baseline)** vs **EB (peaje por franja)** con las métricas: reducción, modal shift, desplazamiento y equidad. |
| **OE5** | Redactar el paper en Overleaf (IEEE) comparando con el benchmark Londres (2003) y proponiendo recomendaciones de política. |

---

## 4. Justificación y Aporte Original

### 4.1 Vacíos de investigación

| # | Vacío identificado | Relevancia |
|---|---|---|
| 1 | No existe simulación ABM de peaje urbano en ciudades andinas latinoamericanas. | Primera evidencia computacional para este contexto geográfico. |
| 2 | No hay evaluación previa de la propuesta concreta para La Carolina. | El SMA puede informar la decisión municipal. |
| 3 | No se ha modelado el efecto combinado peaje + Metro de Quito reciente. | El modal shift (15 % desde autos) es muy reciente y no modelado. |
| 4 | La mayoría de papers usan semáforos reactivos simples. | El gestor BDI con tarifa dinámica eleva el rigor metodológico. |

### 4.2 Contribución científica

Primera simulación multiagente BDI con datos geoespaciales reales que evalúa una zona de cobro
por congestión en una ciudad andina latinoamericana con Metro reciente, flota en crecimiento
crítico y debate de política pública activo.

---

## 5. Marco Teórico

### 5.1 Por qué ABM es la metodología correcta

- **Heterogeneidad real** — los conductores tienen distinto *willingness-to-pay*, acceso al
  Metro y flexibilidad de ruta; los modelos agregados los promedian y pierden la información de
  equidad.
- **Emergencia del sistema** — el desplazamiento periférico emerge de cientos de decisiones
  individuales y no se predice con ecuaciones macro.
- **Análisis contrafactual** — permite variar tarifa, polígono o integración con Metro y observar
  el impacto sin implementar nada físicamente.

### 5.2 Arquitectura BDI (Rao y Georgeff, 1995)

| Componente | En el agente conductor |
|---|---|
| **Creencias** | Posición en la red, tarifa vigente, tiempo estimado por ruta, tercera placa activa/inactiva. |
| **Deseos** | Minimizar tiempo y costo; en NSE bajo, maximizar la probabilidad de llegar (aun con cambio modal). |
| **Intenciones** | Pagar y mantener ruta · reroutear por vías periféricas · cambiar al Metro. |

### 5.3 Alineación con el syllabus (Unidad 3)

| Concepto del syllabus | Implementación |
|---|---|
| Comunicación | El conductor consulta la tarifa al punto de control; el gestor AMT señala ajustes a los 5 puntos. |
| Coordinación | El gestor AMT ajusta tarifas según la densidad global del polígono buscando un óptimo sistémico. |
| Negociación | Si la tarifa supera el umbral de utilidad del agente, éste rechaza y ejecuta una intención alternativa. |
| Arquitecturas FIPA / Retsina | El gestor AMT actúa como facilitador FIPA: registra los puntos de control y difunde política tarifaria. |
| Modelamiento de entorno | Entorno parcialmente observable, dinámico y continuo: el conductor ve su vecindad; el gestor, todo el polígono. |

---

## 6. Datos Reales de Calibración

### 6.1 Contexto vehicular del DMQ

| Dato | Valor | Fuente |
|---|---|---|
| Vehículos en circulación | +600 000 en el DMQ | INEC, Anuario Transporte 2023 |
| Crecimiento del parque | +5.6 % anual (2018–2023) | AMT — Informe de Movilidad DMQ |
| Velocidad media hora pico | 14–18 km/h (corredores norte) | AMT / Google Maps Traffic API |
| Cobertura tercera placa | ~20 % de la flota en días hábiles | Ordenanza Metropolitana DMQ |

### 6.2 Metro de Quito (fuente directa de calibración)

| Indicador | Valor | Fuente |
|---|---|---|
| Usuarios diarios | ~170 000 viajes/día (2025) | Boletín EPMMQ #2, feb 2025 |
| Provenían de auto | **15 % ≈ 10 000 autos/día removidos** | Encuesta EPMMQ, dic 2023–feb 2024 |
| Uso diario consolidado | 65 % usa el Metro a diario (+5 pp vs 2024) | Boletín EPMMQ #2, feb 2025 |
| Estaciones de la zona | Iñaquito · La Carolina | Metro de Quito |
| Meta municipal | 370 000 viajes/día a mediano plazo | Primicias, mar 2024 |

> **Dato clave:** el 15 % de usuarios del Metro provino de vehículo particular (~10 000 autos/día
> ya removidos). La infraestructura de absorción modal **ya existe y funciona**; la simulación
> proyecta cuántos autos *adicionales* removería el peaje superpuesto a este efecto base.

---

## 7. Diseño del Sistema Multiagente

### 7.1 Área de estudio — Polígono La Carolina

| Límite | Vía |
|---|---|
| Norte | Av. Naciones Unidas |
| Sur | Av. De la República |
| Este | Av. De los Shyris / Av. Eloy Alfaro |
| Oeste | Av. Amazonas / Av. América |
| Puntos de control | 5 accesos principales semaforizados (C1–C5) |
| Estaciones Metro | Iñaquito (norte) · La Carolina (sur) |

### 7.2 Los agentes del sistema

| Agente | Arquitectura | Instancias | Rol |
|---|---|---|---|
| **Conductor / Vehículo** (`ConductorBDI`) | BDI + Utilidad | 300 inicial + inyección en pico (~840) | Agente central. Decide pagar, reroutear o cambiar al Metro según **NSE y tipo de vehículo** (ver §7.5) y utilidad. |
| **Punto de control (peaje)** (`PuntoControl`) | Reactivo → BDI | 5 (C1–C5) | Cobra en los accesos. Publica la tarifa de referencia; el gestor le escribe la tarifa vigente. |
| **Estación de Metro** (`EstacionMetro`) | Reactivo / Pasivo | 2 (Iñaquito, La Carolina) | Atractor de modal shift; capacidad ~8 000/h por estación. |
| **Gestor AMT / Municipio** (`GestorAMT`) | BDI deliberativo | 1 | Visión global. Delibera cada 30 ciclos sobre creencias (densidad v/c de la zona, velocidad, tendencia, saturación Metro) → intención MANTENER/SUBIR/BAJAR/SUSPENDER, y escala **todas** las tarifas con `factor_gestor` (activo en EB). |
| **Red vial (entorno)** (`road`) | Pasivo | 1 (continua) | Red interior vs. rutas de desvío externas. `speed_coeff` decae con la ocupación ponderada. Importada de QGIS/OSM. |
| **Transporte público (bus)** | Reactivo | 30 (~10 %) | Implementado como `tipo_vehiculo = "BUS"` dentro de `ConductorBDI` (no especie aparte). Exonerado del peaje; siempre RUTA_DIRECTA y NSE Bajo. |

### 7.3 Función de utilidad del conductor

El agente evalúa tres alternativas mediante una función de utilidad multicriterio:

```
U(alternativa) = w₁ · (1 / tiempo_viaje) + w₂ · (1 / costo) + w₃ · comodidad_percibida
```

Los pesos `w₁, w₂, w₃` varían según el perfil socioeconómico: un conductor de nivel alto pondera
más la comodidad y menos el costo; uno de nivel bajo maximiza el ahorro aunque implique más
tiempo. **Esta heterogeneidad es el mecanismo que permite el análisis de equidad**: quién paga,
quién rerutea y quién se ve forzado al Metro.

Valores calibrados en los modelos finales (`*2`):

| NSE | Proporción | `wtp` (USD) | w₁ tiempo | w₂ costo | w₃ comodidad | Umbral congestión |
|---|---:|---:|---:|---:|---:|---:|
| Alto | 15 % | 3.00 | 0.35 | 0.15 | 0.50 | 0.40 |
| Medio | 45 % | 2.25 | 0.35 | 0.35 | 0.30 | 0.55 |
| Bajo | 40 % | 0.50 | 0.20 | 0.65 | 0.15 | 0.70 |

La utilidad de RUTA_DIRECTA se penaliza (−0.5) cuando la **tarifa efectiva supera el `wtp`**, lo
que fuerza al agente a una alternativa (rerouteo o Metro). El conductor delibera solo cuando hay
peaje percibido, congestión sobre su umbral, o periódicamente en hora pico.

### 7.4 Integración de la tercera placa

Precondición evaluada al inicio de cada ciclo:

- **Restricción activa ese día** — el agente no puede ingresar al polígono sea cual sea la
  tarifa; solo puede reroutear o usar el Metro.
- **Sin restricción** — evalúa normalmente su función de utilidad ante el cobro.
- **Exonerado estructural** (emergencias, transporte público) — acceso libre, sin cobro, en todos
  los escenarios.

### 7.5 Flota heterogénea: tipos de vehículo y tarifas diferenciadas

El conductor tiene **dos identidades superpuestas**: su NSE (§7.3) y su **tipo de vehículo**, que
fija velocidad, ocupación de vía (`factor_capacidad_via`) y tratamiento tarifario. La flota inicial
de 300 agentes se reparte así:

| Tipo | Flota | Factor de vía | Tarifa pico (USD) | Notas |
|---|---:|---:|---:|---|
| Moto | 45 (15 %) | 0.3 | **Exonerado** | Mayor agilidad; umbral de congestión reducido. |
| Auto | 165 (55 %) | 1.0 | 2.00 | Referencia publicada en los gates. |
| SUV | 45 (15 %) | 1.5 | 3.00 | `wtp` escalado ×1.3. |
| Bus | 30 (10 %) | 3.0 | **Exonerado** | Ruta fija; NSE Bajo forzado. |
| Carga | 15 (5 %) | 2.5 | 3.00 | Mayor impacto vial. |

**Tarifa efectiva.** Cada agente paga la tarifa base de su propio tipo (no un ratio sobre el auto);
los exonerados pagan 0. La tarifa la calcula como `tarifa_base_tipo × factor_gestor`.

**Señal tarifaria dinámica (EB).** Las tarifas base solo se cobran en franja pico (07–10 h, 17–20 h)
y son escaladas por el **`GestorAMT`** mediante un multiplicador global `factor_gestor`, que mueve
todas las tarifas conservando sus proporciones dentro del rango `[$0.50, $3.00]` (pasos de $0.25).
Esto hace que el peaje sea **diferenciado por tipo** y **dinámico en el tiempo** a la vez.

> **Caveat de implementación.** En los modelos configurables `*2` los 5 puntos de control se colocan
> de forma interactiva (doble clic) y la zona de cobro es su envolvente convexa; no se persisten, por
> lo que la corrida no es aún reproducible en batch/autorun (ver `ESTADO_PROYECTO.md`, frente C).

---

## 8. Escenarios de Simulación

Se implementan **dos** escenarios al mismo horizonte (06:00–22:00). A y C quedan como trabajo
futuro en el paper.

| Escenario | Descripción | Parámetros | Propósito |
|---|---|---|---|
| **E0** ✓ | Baseline sin peaje — estado actual | Pico y placa activo, sin cobro, Metro libre | Calibración contra AMT; línea base obligatoria. |
| **EB** ✓ | Peaje por franja horaria — modelo Londres | $0 fuera de pico; en pico (07–10 h, 17–20 h) **tarifas diferenciadas por tipo** (Auto $2 · SUV/Carga $3 · Moto/Bus exentos), ajustadas dinámicamente por el `GestorAMT` en `[$0.50, $3.00]`; con tercera placa | Benchmark directo con el LCC; evalúa reducción y equidad. |
| A (futuro) | Peaje fijo 24 h ($0.50–$1.00) | Tarifa plana sin distinción horaria | Extensión del paper. |
| C (futuro) | Tarifa dinámica BDI en tiempo real | Ajuste cada 5 min por el gestor AMT | Estado del arte; investigación futura. |

---

## 9. Métricas de Evaluación

| Variable dependiente | Indicador | Unidad | Benchmark Londres 2003 |
|---|---|---|---|
| Reducción vehicular en polígono | % Δ flujo | veh/h | −27 % autos (6 meses); −18 % volumen (año 1) |
| Modal shift hacia Metro | % → Metro | pasajeros/h | Cambio significativo hacia bus y tube |
| Desplazamiento periférico | Δ Q_ext | veh/h | También redujo el tráfico en vías no cobradas |
| Velocidad media en polígono | km/h | km/h | +20 % a los 6 meses |
| Equidad socioeconómica | Δ Gini modal | índice 0–1 | Beneficios progresivos (J. Urban Econ. 2024) |
| Recaudación estimada | $/hora simulada | USD | £5/día inicial (≈ $6 USD 2003); Quito propone $2–$3 diferenciado |
| Recaudación y pagos por tipo | USD y nº de pagos | por tipo | Hace observable la diferenciación (Auto/SUV/Carga; Moto/Bus exentos) |

> **Columnas reales exportadas (modelos `*2`).** El CSV de EB incluye, además de las métricas
> agregadas: la tarifa de referencia (`tarifa_vigente_usd`), las decisiones desagregadas por NSE
> (`directo_*`, `metro_*`, `rerouta_*`) y la diferenciación tarifaria por tipo
> (`recaud_auto/suv/carga`, `pagos_auto/suv/carga`). El pipeline Python deriva de las decisiones
> NSE los proxies de flujo (`flujo_poligono`, `flujo_externo`) y el `Δ Gini modal`. La lista de
> columnas debe mantenerse en sincronía en tres sitios (header `save` del `init`, fila de
> `exportar_metricas` y `COLUMNAS_*` en `01_process_results.py`).

---

## 10. Implementación Técnica

### 10.1 Stack tecnológico

| Componente | Herramienta | Justificación |
|---|---|---|
| Motor de simulación | GAMA Platform 2.0 + GAML | Soporte nativo GIS/ABM y visualización espacial (Contreras et al., 2023). |
| Datos geoespaciales | QGIS 3.x + OpenStreetMap | Exportación GeoJSON/Shapefile compatible con GAMA; software libre. |
| Documentación | Overleaf (LaTeX + BibTeX) | Requerimiento del syllabus (U4, semana 16). |
| Control de versiones | Git + GitHub | Trabajo colaborativo en GAML y LaTeX. |
| Análisis | Python (pandas, matplotlib) | Procesamiento de las métricas exportadas por GAMA. |

### 10.2 Pipeline de datos geoespaciales

1. Descargar la red vial OSM de La Carolina con QuickOSM (plugin de QGIS).
2. Limpieza topológica: nodos duplicados, sentidos viales y recorte al bounding box del polígono.
3. Añadir capas: polígono de cobro (5 puntos de control), estaciones Metro, densidad INEC.
4. Exportar a GeoJSON en **EPSG:32717 (UTM 17S)** para coordenadas métricas precisas.
5. Importar en GAMA mediante la capa `road_network` y validar visualmente el entorno.

---

## 11. Roadmap de Implementación — 8 Semanas

| Semanas | Sprint | Entregable |
|---|---|---|
| 1–2 | **S0 — Setup** | QGIS configurado, red OSM importada, polígono con 5 puntos. Repo Git y plantilla Overleaf montados. |
| 3–4 | **S1 — Agentes** | Conductor BDI funcional (creencias, utilidad, 3 intenciones). Punto de control reactivo. E0 corriendo con 300 agentes. *(Evaluación formativa 25 %, semana 4.)* |
| 5–6 | **S2 — Escenarios** | EB (peaje por franja) + gestor AMT con tarifa dinámica. Métricas CSV: flujo, modal shift, velocidad. Metodología en Overleaf. |
| 7–8 | **S3 — Paper** | Comparativa E0 vs EB, gráficas Python, paper completo en Overleaf con referencias BibTeX. *(Evaluación sumativa 30 %, semana 8.)* |

---

## 12. Benchmark — London Congestion Charge (2003)

Referente empírico directo del Escenario B (peaje por franja, L–V, 7am–6pm).

| Indicador | Resultado Londres | Relevancia para Quito |
|---|---|---|
| Reducción vehicular | −27 % autos (6 meses); −18 % volumen (año 1) | Fija el umbral mínimo de validación (≥ 20 %). |
| Velocidad media | +20 % en 6 meses | Métrica de efectividad comparable. |
| Reducción de congestión | −30 % año 1 (Atmos. Environ. 2012) | Relación no lineal entre reducción y congestión. |
| Desplazamiento periférico | También redujo vías no cobradas (J. Urban Econ. 2024) | Desafía el supuesto de desplazamiento; el modelo debe verificarlo. |
| Equidad | Beneficios progresivos en zonas de bajos ingresos | Relevante para la discusión de política pública. |
| Diferencia clave | Londres tenía transporte público maduro antes del peaje | El Metro opera desde dic. 2023: ¿es 2026 demasiado pronto? |

---

## 13. Distribución del Trabajo

| Persona | Rol | Entregable concreto |
|---|---|---|
| P1 | Geoespacial (QGIS) | `.geojson` validado para GAMA + mapa del polígono para el paper. |
| P2 | Datos y calibración | CSV de parámetros BDI por NSE + tabla de calibración AMT. |
| P3 | GAML (principal) | `ConductorBDI` funcional con las tres intenciones. |
| P4 | GAML (soporte) | Punto de control, gestor AMT, estación Metro, escenario EB con salida CSV. |
| P5 | Paper y análisis | Overleaf desde semana 1, gráficas Python, consolidación final. |

---

## 14. Referencias Bibliográficas (IEEE)

**Metodología ABM y tarificación por congestión**

- [1] *MAGT-toll: A multi-agent reinforcement learning approach to dynamic traffic congestion pricing.* PLOS ONE, nov. 2024. DOI: 10.1371/journal.pone.0313828.
- [2] *Controlling Traffic Congestion in Urbanised City: A Framework Using Agent-Based Modelling and Simulation Approach.* ISPRS Int. J. Geo-Inf. 12(6), 226, 2023. DOI: 10.3390/ijgi12060226.
- [3] *Congestion pricing in a real-world oriented agent-based simulation context.* Transport Policy, 2019. DOI: 10.1016/j.tranpol.2017.12.002.
- [4] *Agent-based models in urban transportation: review, challenges, and opportunities.* European Transport Research Review, Springer, 2023. DOI: 10.1186/s12544-023-00590-5.

**Benchmark — London Congestion Charge**

- [5] *The Cost of Traffic: Evidence from the London Congestion Charge.* Journal of Urban Economics, 2020.
- [6] *The city-wide effects of tolling downtown drivers: Evidence from London's congestion charge.* Journal of Urban Economics, 2024. DOI: 10.1016/j.jue.2024.103636.
- [7] *The impact of the London congestion charging scheme on air quality.* Atmospheric Environment, 2012. PMID: 21830496.

**Datos locales — Quito**

- [8] *Metro de Quito — Boletín Estadístico #2.* EPMMQ, febrero 2025. metrodequito.gob.ec.
- [9] *Encuesta de satisfacción de usuarios del Metro de Quito.* EPMMQ, dic 2023–feb 2024.
- [10] *Anuario de Estadísticas de Transporte 2023.* INEC, Ecuador, 2023.
- [11] N. Gómez-Cruz, *Vida artificial: Ciencia e ingeniería de Sistemas complejos*, 2013.

---

## 15. Estructura del Paper Académico (IEEE, Overleaf)

| Sección | Contenido |
|---|---|
| **Abstract** | 250 palabras: pregunta, metodología ABM/BDI, datos, escenarios y hallazgos. |
| **1. Introducción** | Contexto DMQ, propuesta municipal, justificación del ABM, pregunta e hipótesis. |
| **2. Marco teórico** | ABM en transporte, arquitectura BDI, congestion pricing (refs. [1]–[4]). |
| **3. Metodología** | SMA, agentes, función de utilidad, entorno GAMA/QGIS, escenarios E0/EB, calibración. |
| **4. Resultados** | Tablas comparativas E0 vs EB; gráficas de flujo, modal shift y velocidad. |
| **5. Discusión** | Benchmark Londres (refs. [5]–[7]), equidad, implicaciones para el Plan de Movilidad. |
| **6. Conclusiones** | Validación de la hipótesis, limitaciones, extensión a los escenarios A y C. |
| **Referencias** | 11 fuentes en formato BibTeX IEEE. |

---

*Universidad Central del Ecuador — Facultad de Ingeniería y Ciencias Aplicadas.
Asignatura Sistemas Colaborativos (TGP09BFT03), Noveno Semestre, 2026.*
