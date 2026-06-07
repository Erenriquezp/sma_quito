 

UNIVERSIDAD CENTRAL DEL ECUADOR 

Facultad de Ingeniería y Ciencias Aplicadas 

Carrera de Computación 

  

Simulación Multiagente del Impacto de una Zona de Cobro por Congestión en el Sector Parque La Carolina 

Evaluación de Políticas de Movilidad Urbana en Quito Mediante Arquitectura BDI y Datos Geoespaciales Reales 

  

 

Asignatura: 

Sistemas Colaborativos (TGP09BFT03) — Noveno Semestre 

Docente: 

Luis Felipe Borja 

Período Académico: 

2026 – 2026 

 

 

1. Información General del Proyecto 

Título 

Simulación Multiagente del Impacto de una Zona de Cobro por Congestión en el Sector Parque La Carolina 

Título en inglés 

BDI-based Multi-Agent Simulation of Congestion Pricing around Parque La Carolina: A Policy Evaluation Tool for Quito's Urban Mobility 

Asignatura 

Sistemas Colaborativos — TGP09BFT03 

Unidades curriculares 

Unidad 3 (Sistemas Multiagentes) y Unidad 4 (Simulación y Modelamiento SMA) 

Herramientas principales 

GAMA Platform 2.0, GAML, QGIS 3.x, Overleaf (LaTeX) 

Duración estimada 

8 semanas (semanas 9–16 del semestre) 

Equipo 

5 integrantes (nivel de experiencia intermedio-bajo en herramientas) 

 

2. Planteamiento del Problema 

2.1 Contexto y motivación 

El Distrito Metropolitano de Quito (DMQ) registra más de 600 000 vehículos en circulación activa (INEC, Anuario de Transporte 2023), con un crecimiento anual del parque automotor que supera la capacidad de expansión de la infraestructura vial. El sector del Parque La Carolina concentra algunos de los corredores de mayor congestión de la capital: las avenidas Naciones Unidas, Amazonas, De los Shyris, Eloy Alfaro y 6 de Diciembre convergen en una zona de alto valor comercial y financiero que actualmente no cuenta con ningún mecanismo de gestión de demanda vehicular. 

 

El Municipio del DMQ, bajo la administración del Alcalde Pabel Muñoz, ha incluido en el Plan Maestro de Movilidad la propuesta conceptual de implementar una zona de cobro por congestión en el sector La Carolina. Sin embargo, a la fecha no existe ningún análisis cuantitativo publicado que evalúe la viabilidad de esta medida en el contexto específico de Quito, considerando el comportamiento heterogéneo de los usuarios, la oferta reciente del Metro de Quito (en operación desde diciembre de 2023) y el efecto preexistente del sistema de restricción vehicular "tercera placa". 

 

Este vacío de evidencia computacional justifica el desarrollo de un Sistema Multiagente (SMA) que simule el comportamiento emergente de la movilidad urbana bajo diferentes políticas de tarificación. La metodología de Modelado Basado en Agentes (ABM, por sus siglas en inglés) resulta idónea para este problema, dado que permite representar la heterogeneidad individual de los conductores, modelar la emergencia de fenómenos sistémicos como el desplazamiento de tráfico hacia vías periféricas, y evaluar el impacto diferenciado por nivel socioeconómico. 

 

2.2 Pregunta de investigación 

¿Es la zona de cobro por congestión en el sector La Carolina una política viable para reducir el tráfico vehicular en Quito, considerando el comportamiento heterogéneo de los usuarios, la oferta del Metro de Quito y el efecto del sistema de tercera placa? 

Esta pregunta no tiene respuesta publicada para Quito. La simulación propuesta constituiría la primera evidencia computacional disponible para informar una decisión de política pública de alta relevancia para el DMQ. 

 

2.3 Hipótesis principal 

La implementación de una zona de cobro por congestión con tarifa dinámica BDI en el polígono La Carolina reduce el volumen vehicular de paso en al menos un 20 %, incrementa el uso del Metro de Quito y no genera un desplazamiento crítico del tráfico hacia vías periféricas, en comparación con el escenario sin peaje. Este umbral de reducción se establece tomando como referencia el 27 % logrado por el London Congestion Charge en sus primeros seis meses de operación (2003). 

 

3. Objetivos 

3.1 Objetivo general 

Desarrollar un Sistema Multiagente (SMA) con arquitectura BDI e integración de datos geoespaciales reales que simule y evalúe el impacto de una zona de cobro por congestión en el sector Parque La Carolina de Quito, comparando un escenario baseline con un escenario de peaje por franja horaria, y documentando los resultados en un paper académico estructurado. 

 

3.2 Objetivos específicos 

Modelar el polígono de cobro alrededor del Parque La Carolina con datos geoespaciales reales exportados desde QGIS (red vial OSM, puntos de control, estaciones del Metro de Quito, densidad poblacional INEC), en formato compatible con GAMA Platform. 

Diseñar e implementar agentes-vehículo con arquitectura BDI y función de utilidad diferenciada por perfil socioeconómico, que modelen la decisión de pagar el peaje, reroutear por vías periféricas o cambiar al Metro de Quito. 

Integrar el efecto de la tercera placa como restricción preexistente sobre la flota vehicular simulada, calibrando el modelo con datos oficiales de flujo vehicular de la Agencia Metropolitana de Tránsito (AMT). 

Ejecutar y comparar dos escenarios de simulación: Escenario 0 (baseline sin peaje, estado actual) y Escenario B (peaje por franja horaria replicando el modelo Londres), midiendo las métricas definidas: reducción vehicular, modal shift, desplazamiento periférico y equidad. 

Redactar un documento académico en Overleaf (LaTeX) que compare los resultados obtenidos con el modelo del London Congestion Charge (2003) y proponga recomendaciones de política para el Plan Maestro de Movilidad del DMQ. 

 

4. Justificación y Aporte Original 

4.1 Vacíos de investigación identificados 

La revisión de literatura en Google Scholar y Scopus identifica cuatro vacíos que este proyecto aborda directamente: 

 

Gap 

Descripción 

Relevancia para el proyecto 

1 

No existe simulación ABM de peaje urbano en ciudades andinas latinoamericanas 

Posiciona el proyecto como primera evidencia computacional para este contexto geográfico 

2 

No existe evaluación previa de la propuesta concreta del Alcalde Muñoz para La Carolina 

El SMA puede informar directamente la toma de decisión municipal 

3 

No hay análisis del efecto combinado peaje + Metro de Quito reciente (operativo desde dic. 2023) 

Los datos de modal shift (15 % desde autos = ~10 000 vehículos/día menos) son muy recientes y no han sido modelados 

4 

La arquitectura BDI para agentes gestores con tarifa dinámica es estado del arte 

La mayoría de papers usan semáforos reactivos simples; el Escenario B eleva el rigor metodológico 

 

4.2 Contribución científica 

Primera simulación multiagente BDI con datos geoespaciales reales que evalúa la viabilidad de una zona de cobro por congestión en el contexto de una ciudad andina latinoamericana con Metro reciente, flota vehicular en crecimiento crítico y debate de política pública activo. 

 

5. Marco Teórico 

5.1 Por qué el ABM es la metodología correcta 

El modelado basado en agentes (ABM) supera a los modelos de tráfico agregados en tres dimensiones críticas para este problema: 

 

Heterogeneidad real: los conductores presentan diferente willingness-to-pay, distinto acceso al Metro según su origen-destino y diferente flexibilidad de ruta. Los modelos de ecuaciones diferenciales los promedian, perdiendo la información más valiosa para el análisis de equidad. 

Emergencia del sistema: el desplazamiento de tráfico hacia vías periféricas es un fenómeno emergente que no puede predecirse con ecuaciones de nivel macro. Surge de las decisiones individuales de cientos de agentes interactuando simultáneamente con la red vial. 

Análisis contrafactual: es posible modificar parámetros (tarifa, polígono, integración con Metro) y observar el impacto sin implementar nada físicamente. Exactamente lo que el Municipio necesita antes de comprometer infraestructura. 

 

5.2 Arquitectura BDI (Creencias, Deseos, Intenciones) 

La arquitectura BDI, formalizada por Rao y Georgeff (1995), modela agentes deliberativos cuya conducta emerge de tres componentes: 

 

Creencias (Beliefs): el estado informacional del agente sobre el mundo. En el agente conductor: posición en la red vial, tarifa actual en el punto de control, tiempo estimado de viaje por cada ruta disponible, restricción de tercera placa activa o inactiva. 

Deseos (Desires): los objetivos que el agente aspira a satisfacer. En este modelo: minimizar tiempo de viaje, minimizar costo total del desplazamiento y, en agentes de nivel socioeconómico bajo, maximizar la probabilidad de llegar al destino (aun si implica cambio modal). 

Intenciones (Intentions): el plan de acción comprometido tras el proceso de deliberación. El agente elige entre tres intenciones posibles: pagar el peaje y mantener ruta, reroutear por vías periféricas, o cambiar al Metro de Quito. 

 

5.3 Sistemas multiagentes (SMA) — alineación con el syllabus 

Conforme a la Unidad 3 del syllabus de la asignatura (Sistemas Colaborativos, UCE 2026), el proyecto implementa los conceptos evaluables de la siguiente manera: 

 

Concepto del syllabus 

Implementación en el proyecto 

Comunicación entre agentes 

El conductor BDI consulta al punto de control la tarifa vigente; el gestor AMT emite señales de ajuste a los 5 puntos de control simultáneamente. 

Coordinación entre agentes 

El gestor AMT coordina la respuesta colectiva del sistema ajustando tarifas en función de la densidad global del polígono, buscando un óptimo sistémico que ningún agente individual puede alcanzar. 

Negociación entre agentes 

El punto de control negocia implícitamente con el conductor: si la tarifa supera el umbral de utilidad del agente, éste rechaza la transacción y ejecuta una intención alternativa (rerouteo o cambio modal). 

Arquitecturas FIPA / Retsina 

El agente gestor AMT actúa como agente facilitador siguiendo el patrón FIPA: registra a los agentes de control, mantiene el directorio de servicios del polígono y difunde mensajes de política tarifaria. 

Modelamiento de entorno 

Entorno parcialmente observable, dinámico y continuo: cada conductor BDI percibe solo su vecindad inmediata en la red vial, mientras el gestor AMT tiene visión global del polígono. 

 

6. Datos Reales de Calibración 

6.1 Contexto vehicular del DMQ 

Dato 

Valor 

Fuente 

Vehículos en circulación 

+600 000 en el DMQ 

INEC, Anuario Transporte 2023 

Crecimiento del parque 

+5.6 % anual promedio (2018–2023) 

AMT — Informe de Movilidad DMQ 

Velocidad media hora pico 

14–18 km/h en corredores del norte (La Carolina) 

AMT / Google Maps Traffic API 

Cobertura tercera placa 

Restringe ~20 % de la flota en días hábiles, por dígito de placa 

Ordenanza Metropolitana DMQ 

 

6.2 Metro de Quito — datos de operación (fuente directa de calibración) 

Indicador 

Valor 

Fuente 

Usuarios diarios promedio 

~170 000 viajes/día (consolidado 2025) 

Boletín EPMMQ #2, feb 2025 

Usuarios que venían de auto 

15 % (~10 000 autos/día menos ya removidos del sistema) 

Encuesta EPMMQ, dic 2023–feb 2024 

Uso diario consolidado 

65 % usa el Metro a diario (+5 pp vs 2024) 

Boletín EPMMQ #2, feb 2025 

Estaciones zona de estudio 

El Labrador (norte) e Iñaquito (sur) — conectan toda la zona La Carolina 

Metro de Quito / Wikipedia 

Meta municipal 

370 000 viajes/día a mediano plazo 

Primicias, mar 2024 

 

El dato más relevante para el modelo: el 15 % de usuarios actuales del Metro provino de vehículo particular, equivalente a aproximadamente 10 000 autos/día ya removidos. Esto demuestra que la infraestructura de absorción modal ya existe y ya funciona. La simulación proyectará cuántos autos adicionales se removerían con el peaje superpuesto a este efecto base. 

 

7. Diseño del Sistema Multiagente 

7.1 Área de estudio — Polígono La Carolina 

El polígono de cobro propuesto delimita el área de mayor congestión del sector financiero y comercial del norte de Quito: 

 

Límite Norte 

Av. Naciones Unidas 

Límite Sur 

Av. De la República 

Límite Este 

Av. De los Shyris / Av. Eloy Alfaro 

Límite Oeste 

Av. Amazonas / Av. América 

Puntos de control 

5 accesos principales semaforizados (C1–C5) 

Estaciones Metro 

El Labrador (norte del polígono) e Iñaquito (sur del polígono) 

 

7.2 Especificación de los seis tipos de agentes 

Agente 

Arquitectura 

Instancias 

Rol en el sistema 

Conductor / Vehículo 

BDI + Utilidad 

300–500 

Agente central. Decide pagar peaje, reroutear o cambiar a Metro según perfil socioeconómico y función de utilidad. 

Punto de control (peaje) 

Reactivo → BDI 

5 

Cobra el peaje en accesos al polígono. Comunica tarifa vigente al gestor AMT y a los conductores. 

Estación de Metro 

Reactivo / Pasivo 

2 (El Labrador, Iñaquito) 

Atractor de modal shift. Tiene capacidad de absorción limitada; genera congestión propia si se satura. 

Gestor AMT / Municipio 

BDI deliberativo 

1 

Visión global del polígono. Ajusta tarifas según densidad vehicular en tiempo de simulación (activo en Escenario B). 

Red vial (entorno) 

Pasivo 

1 (continua) 

Entorno diferenciado: red interior del polígono vs. rutas de desvío externas. Importado desde QGIS/OSM. 

Transporte público (bus/Trole) 

Reactivo 

Variable 

Exonerado del peaje. Compite con el Metro por captación modal en conductores que deciden no pagar. 

 

7.3 Función de utilidad del agente conductor BDI 

El agente conductor evalúa tres alternativas mediante una función de utilidad multicriterio: 

 

U(alternativa) = w₁ · (1 / tiempo_viaje) + w₂ · (1 / costo) + w₃ · comodidad_percibida 

 

Donde los pesos w₁, w₂, w₃ varían según el perfil socioeconómico del agente. Un conductor de nivel alto asigna mayor peso a la comodidad y menor al costo; un conductor de nivel bajo maximiza el ahorro monetario incluso si implica mayor tiempo de viaje. Esta heterogeneidad es el mecanismo que permite analizar la equidad de la política: quién paga, quién rerouta y quién se ve forzado al Metro. 

 

7.4 Integración de la tercera placa 

La restricción vehicular de tercera placa se modela como una precondición de activación del agente conductor, evaluada al inicio de cada ciclo de simulación: 

 

Exento con restricción activa ese día: el agente no puede ingresar al polígono independientemente de la tarifa. Su única intención posible es reroutear o usar el Metro. 

Sin restricción activa: el agente evalúa normalmente su función de utilidad ante el cobro. 

Exonerado estructural (emergencias, transporte público): acceso libre sin cobro en todos los escenarios. 

 

8. Escenarios de Simulación 

En consonancia con los recursos del equipo y el tiempo disponible (8 semanas), el proyecto implementa dos escenarios. Los escenarios A y C quedan documentados como trabajo futuro en el paper académico. 

 

Escenario 

Descripción 

Parámetros 

Propósito académico 

Escenario 0 ✓ 

Baseline sin peaje — estado actual del DMQ 

Pico y placa activo, sin cobro, Metro disponible como alternativa libre 

Calibración contra datos AMT. Línea base obligatoria para validar el modelo. 

Escenario B ✓ 

Peaje por franja horaria — modelo Londres 

$0 fuera de pico; $1.50–$2.00 en hora pico (7–10am y 5–8pm); vinculado a tercera placa 

Benchmark directo con London Congestion Charge. Evalúa reducción vehicular y equidad. 

Escenario A (trabajo futuro) 

Peaje fijo 24h ($0.50–$1.00) 

Tarifa plana, sin distinción horaria 

Requiere iteración adicional. Propuesto para extensión del paper. 

Escenario C (trabajo futuro) 

Tarifa dinámica BDI en tiempo real 

Ajuste cada 5 min por gestor AMT BDI 

Estado del arte. Alcance de investigación futura. 

 

9. Métricas de Evaluación 

Variable dependiente 

Indicador 

Unidad 

Benchmark referencia (Londres 2003) 

Reducción vehicular en polígono 

% Δ flujo 

Vehículos/hora 

−27 % autos en 6 meses; −18 % volumen año 1 (ScienceDirect, J. Urban Econ.) 

Modal shift hacia Metro 

% → Metro 

Pasajeros/hora 

Cambio significativo hacia bus y tube (TfL, 2003–2012) 

Desplazamiento periférico 

Δ Q_ext 

Vehículos/hora 

Redujo tráfico también en vías no cobradas (J. Urban Econ. 2024) — efecto opuesto al temor del desplazamiento 

Velocidad media en polígono 

km/h 

km/h 

+20 % velocidad media a los 6 meses (ScienceDirect) 

Equidad socioeconómica 

Δ Gini modal 

Índice 0–1 

Beneficios progresivos: redujo tráfico donde viven trabajadores de menores ingresos (J. Urban Econ. 2024) 

Recaudación estimada 

$/hora simulada 

USD 

£5/día tarifa inicial (≈ $6 USD 2003); actualmente £15. Quito: $1.50–$2.00 propuesto. 

 

10. Implementación Técnica 

10.1 Stack tecnológico 

Componente 

Herramienta 

Justificación 

Motor de simulación 

GAMA Platform 2.0 + GAML 

Soporte nativo de GIS, ABM y visualización espacial. Validado en literatura específica de tráfico urbano (Contreras et al., 2023). 

Datos geoespaciales 

QGIS 3.x + OpenStreetMap 

Exportación de red vial en formato GeoJSON/Shapefile compatible con GAMA. Software libre, sin licencia. 

Documentación científica 

Overleaf (LaTeX + BibTeX) 

Requerimiento explícito del syllabus (Unidad 4, semana 16): redacción de documento académico. 

Control de versiones 

Git + GitHub 

Trabajo colaborativo del equipo en el código GAML y el documento LaTeX. 

Análisis de resultados 

Python (pandas, matplotlib) 

Procesamiento de las series de métricas exportadas por GAMA para generación de gráficas del paper. 

 

10.2 Pipeline de datos geoespaciales 

El flujo de integración entre QGIS y GAMA sigue el siguiente proceso, asignable a la Persona 1 del equipo: 

 

Descarga de la red vial OSM del sector La Carolina mediante QuickOSM (plugin de QGIS). 

Limpieza topológica: eliminación de nodos duplicados, corrección de sentidos viales y recorte al bounding box del polígono de cobro. 

Adición de capas: polígono de cobro (5 puntos de control), estaciones Metro (El Labrador, Iñaquito), zonas de densidad poblacional INEC. 

Exportación a GeoJSON (EPSG:32717 — UTM zona 17S para coordenadas métricas precisas en Quito). 

Importación en GAMA mediante la capa road_network y validación visual del entorno simulado. 

 

11. Roadmap de Implementación — 8 Semanas 

Semanas 

Sprint 

Entregable 

Responsables 

1–2 

S0 — Setup 

QGIS configurado, red vial OSM La Carolina importada, polígono de cobro con 5 puntos de control. Repositorio Git inicializado. Estructura del paper en Overleaf montada (plantilla IEEE/ACM). 

P1 (QGIS), P5 (Overleaf), todos en instalación GAMA. 

3–4 

S1 — Agentes 

Agente conductor BDI básico funcional en GAML: creencias, función de utilidad, tres intenciones. Punto de control reactivo implementado. Escenario 0 ejecutándose sin errores con 300 agentes. 

P3 + P4 (GAML). P2 entrega CSV de parámetros calibrados. Evaluación formativa grupal (25 %) — semana 4. 

5–6 

S2 — Escenarios 

Escenario B (peaje franja horaria) implementado. Gestor AMT BDI con lógica de tarifa dinámica por hora. Métricas de salida en CSV: flujo vehicular, modal shift, velocidad media. 

P3 + P4 (GAML). P2 (validación de datos). P5 redacta Metodología en Overleaf. 

7–8 

S3 — Paper 

Análisis comparativo E0 vs EB. Gráficas en Python. Paper completo en Overleaf: Abstract, Introducción, Metodología, Resultados, Discusión (benchmark Londres), Conclusiones, Referencias BibTeX. 

P5 (coordinación paper). P1–P4 contribuyen a secciones específicas. Evaluación sumativa final 2 (30 %) — semana 8. 

 

12. Benchmark — London Congestion Charge (2003) 

El London Congestion Charge constituye el referente empírico más sólido y documentado para comparar los resultados de la simulación. Su esquema de peaje por franja horaria (lunes a viernes, 7am–6pm) es el modelo directo del Escenario B del proyecto. 

 

Indicador 

Resultado real Londres 

Relevancia para la hipótesis Quito 

Reducción vehicular 

−27 % autos a los 6 meses; −18 % volumen año 1 

Establece el umbral mínimo de validación de la hipótesis (≥ 20 %). 

Velocidad media 

+20 % en primeros 6 meses 

Métrica de efectividad directamente comparable. 

Reducción de congestión 

−30 % año 1 (PubMed / Atmos. Environ. 2012) 

Corrobora la relación no lineal entre reducción vehicular y congestión. 

Desplazamiento periférico 

Redujo tráfico también en vías periféricas no cobradas (J. Urban Econ. 2024) 

Desafía el supuesto de desplazamiento. El modelo debe verificar si esto se replica en Quito. 

Equidad 

Beneficios progresivos: menor tráfico en zonas de bajos ingresos 

Relevante para la discusión de política pública con el Municipio. 

Diferencia clave con Quito 

Londres tenía transporte público maduro antes del peaje 

El Metro de Quito opera solo desde dic. 2023. La simulación responde: ¿es 2026 demasiado pronto para el peaje? 

 

13. Distribución del Trabajo en el Equipo 

Persona 

Rol 

Responsabilidades principales 

Entregables concretos 

P1 

Geoespacial 

QGIS: red OSM, polígono cobro, exportación GeoJSON 

Archivo .geojson validado para GAMA + mapa del polígono para el paper. 

P2 

Datos y calibración 

Recopilación datos AMT, Metro INEC. CSV de parámetros. Validación Escenario 0. 

CSV de parámetros BDI por perfil socioeconómico + tabla de calibración. 

P3 

Desarrollo GAML (principal) 

Agente conductor BDI, función de utilidad, tercera placa. 

species conductor_bdi funcional con los tres tipos de intención. 

P4 

Desarrollo GAML (soporte) 

Punto de control, gestor AMT BDI, estación Metro, escenario B. 

Escenarios E0 y EB ejecutando con salida CSV de métricas. 

P5 

Paper y análisis 

Overleaf desde semana 1. Gráficas Python. Consolidación final. 

Paper completo en Overleaf con todas las secciones y referencias BibTeX. 

 

14. Referencias Bibliográficas 

Las siguientes referencias sustentan metodológicamente el proyecto y serán citadas en el paper académico final (formato IEEE): 

 

Metodología ABM y tarificación por congestión 

[1] MAGT-toll: A multi-agent reinforcement learning approach to dynamic traffic congestion pricing. PLOS ONE, nov. 2024. DOI: 10.1371/journal.pone.0313828. Referencia directa de metodología multi-agente para congestion pricing dinámico en redes viales reales. 

[2] Controlling Traffic Congestion in Urbanised City: A Framework Using Agent-Based Modelling and Simulation Approach. ISPRS Int. J. Geo-Inf. 12(6), 226, 2023. DOI: 10.3390/ijgi12060226. Valida GAMA Platform para control de congestión urbana con datos GIS reales. 

[3] Congestion pricing in a real-world oriented agent-based simulation context. Transport Policy, ScienceDirect, 2019. DOI: 10.1016/j.tranpol.2017.12.002. Antecedente metodológico directo: ABM + congestion pricing en red vial real (Berlín). 

[4] Agent-based models in urban transportation: review, challenges, and opportunities. European Transport Research Review, Springer, 2023. DOI: 10.1186/s12544-023-00590-5. Revisión sistemática de ABM en transporte urbano; menciona GAMA explícitamente. 

 

Benchmark — London Congestion Charge 

[5] The Cost of Traffic: Evidence from the London Congestion Charge. Journal of Urban Economics, ScienceDirect, 2020. Fuente primaria del benchmark: −27 % autos a los 6 meses y +20 % velocidad. 

[6] The city-wide effects of tolling downtown drivers: Evidence from London's congestion charge. Journal of Urban Economics, 2024. DOI: 10.1016/j.jue.2024.103636. Estudio más reciente del LCC: efectos de equidad progresiva y reducción periférica (2024). 

[7] The impact of the London congestion charging scheme on air quality. Atmospheric Environment, PubMed, 2012. PMID: 21830496. Documenta −18 % tráfico y −30 % congestión año 1; cuantifica reducción de emisiones. 

 

Datos locales — Quito 

[8] Metro de Quito — Boletín Estadístico #2. EPMMQ, febrero 2025. Disponible en: metrodequito.gob.ec. Perfil oficial de usuarios: 65 % uso diario, 15 % desde vehículo particular, estaciones zona de estudio. 

[9] Encuesta de satisfacción de usuarios del Metro de Quito. EPMMQ, diciembre 2023–febrero 2024. Fuente del dato de modal shift: 15 % ≈ 10 000 autos/día removidos. 

[10] Anuario de Estadísticas de Transporte 2023. INEC — Instituto Nacional de Estadística y Censos, Ecuador, 2023. Datos del parque automotor: +600 000 vehículos en el DMQ, crecimiento anual. 

[11] Vida artificial: Ciencia e ingeniería de Sistemas complejos. N. Gómez-Cruz, 2013. Bibliografía básica oficial de la asignatura. 

 

15. Estructura del Paper Académico (Overleaf) 

El documento académico final, redactado en LaTeX sobre Overleaf, seguirá la siguiente estructura compatible con el formato IEEE Conference Proceedings: 

 

Abstract: síntesis en 250 palabras de la pregunta de investigación, metodología ABM/BDI, datos utilizados, escenarios comparados y principales hallazgos. 

1. Introducción: contexto del DMQ, propuesta del Alcalde Muñoz, justificación del ABM, pregunta de investigación e hipótesis. 

2. Marco teórico y trabajo relacionado: ABM en transporte urbano, arquitectura BDI, congestion pricing (referencias [1]–[4]). 

3. Metodología: descripción del SMA, agentes, función de utilidad, entorno GAMA/QGIS, escenarios E0 y EB, protocolo de calibración. 

4. Resultados: tablas comparativas de métricas E0 vs EB, gráficas de flujo vehicular, modal shift y velocidad media. 

5. Discusión: comparación con benchmark Londres (referencias [5]–[7]), análisis de equidad, implicaciones para el Plan Maestro de Movilidad DMQ. 

6. Conclusiones y trabajo futuro: validación de hipótesis, limitaciones del modelo, extensión hacia Escenarios A y C. 

Referencias: 11 fuentes en formato BibTeX IEEE. 

 

 

Facultad de Ingeniería y Ciencias Aplicadas — Universidad Central del Ecuador 

Asignatura: Sistemas Colaborativos (TGP09BFT03) — Noveno Semestre 2026 