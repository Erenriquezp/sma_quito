# Mejoras UI/UX — Visualización GAMA

> Mejoras visuales (solo bloques `aspect` / `graphics` / `overlay`) de los modelos finales
> `TrafficBase_LaCarolina2.gaml` (E0) y `EB_PeajeHorario2.gaml` (EB). No cambian la lógica
> del SMA ni las métricas. **Última actualización:** 20 jun 2026.

---

## ✅ Hecho (E0 y EB)

- **Vías como mapa de calor de congestión** (`speed_coeff`), paleta pastel: flujo libre
  gris-azulado neutro de fondo; congestión en ámbar → coral. Grosor por ocupación.
- **Línea de tiempo del día** (06–22 h) en el HUD, con franjas pico sombreadas y marcador.
- **Indicador de día** (Lun–Vie / fin de semana) — clarifica el efecto "sin peaje/placa".
- **Zona de cobro** con borde más marcado y etiqueta con sombra para legibilidad.
- **Vehículos con icono + halo de estado**, orientados al rumbo (`heading`), con **slider de
  tamaño** ("Vista" → "Tamaño vehículos"). *Provisional:* todos usan el mismo icono de auto
  (`voit_blue.png`); el halo conserva la lectura de tipo/decisión.

---

## ⏳ Falta (orden sugerido)

### 1. Iconos finales por tipo de vehículo  ⭐ (lo más visible)
Hoy todos los tipos usan el mismo icono de auto. Crear/integrar un icono por tipo
(moto, auto, SUV, bus, carga), vista cenital, PNG con transparencia.
- La orientación por rumbo y el slider de tamaño **ya están listos**; solo falta seleccionar
  el icono según `tipo_vehiculo` (igual que se hace con el color del halo).
- Afinar el offset de rotación (`heading + 180`) si el icono final apunta distinto.

### 2. Estaciones de Metro
- **Anillo de saturación** (verde → ámbar → rojo según `pasajeros_espera / capacidad_hora`)
  en lugar del texto "N esperan".
- Marca/logo del Metro de Quito en vez de la letra "M". Halo pulsante según demanda.

### 3. Pórtico de peaje (`PuntoControl`)
- Forma de arco/portal con barrera que baja al cobrar, en vez de una caja.
- Semáforo del pórtico: verde libre / rojo cobrando.

### 4. Leyenda con mini-iconos
- Usar los mismos iconos del mapa en la leyenda del HUD (hoy son puntos de color), para que
  leyenda y mapa hablen el mismo idioma visual.

### 5. Pulido
- **Unificar paleta entre displays:** el pastel BDI usa `#limegreen` para Metro y el mapa usa
  `#gold` → un color debe significar lo mismo en todas las vistas (definir constantes
  globales `COL_DIRECTA` / `COL_REROUTE` / `COL_METRO` / `COL_PLACA` y reutilizarlas).
- Profundidad 3D: luz direccional + sombra suave bajo agentes/estaciones.
- Tipografía consistente (una familia, números de ancho fijo en los KPIs).

---

## Assets necesarios

| Asset | Formato | Nota |
|---|---|---|
| Iconos por tipo (moto, auto, SUV, bus, carga) | PNG transparente, vista cenital | Base: `includes/voit*.png` (solo auto) |
| Marca/logo Metro de Quito | PNG transparente | Reemplaza la "M" |

Sugerencia: carpeta `gama/includes/icons/`.

---

## Notas

- Todo es visual: tocar solo `aspect` / `graphics` / `overlay`. No cambia el CSV ni el SMA.
- **Replicar en E0 y EB** (no comparten código; hoy están en paridad).
- **Rendimiento:** las vías usan `refresh: true` para el heatmap; si un mapa muy grande va
  lento, bajar a `refresh: false` (se pierde la animación de congestión).
- No se puede compilar GAML aquí: validar en GAMA tras cada cambio (sobre todo tamaños y
  offset de rotación, que dependen de la escala del mapa).
