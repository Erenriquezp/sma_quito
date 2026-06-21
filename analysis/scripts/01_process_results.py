#!/usr/bin/env python3
"""
01_process_results.py
─────────────────────────────────────────────────────────────────────────────
Lee los CSV exportados por GAMA Platform y los normaliza en un DataFrame
limpio y estandarizado, listo para análisis comparativo.

Uso:
    python 01_process_results.py

Entradas:  ../../gama/outputs/E0_metricas.csv   ← baseline (escenario "E0")
           ../../gama/outputs/EB_metricas.csv   ← peaje    (escenario "EB")
Salidas:   ../results/E0_processed.csv
           ../results/EB_processed.csv
           ../results/combined.csv
           ../results/resumen_estadistico.csv

v2 — junio 2026:
  - Escenarios estandarizados: E0 (baseline) y EB (peaje); flota heterogénea
  - Rellena con cero recaudacion_acum_usd y nb_restringidos_placa si ausentes
  - Filtra buses del análisis de equidad NSE (directo_nse_bajo_corr)
  - Columnas alineadas con el CSV real de GAMA (20 columnas con header)

Autores: Equipo SMA Quito — UCE Sistemas Colaborativos 2026
─────────────────────────────────────────────────────────────────────────────
"""

import sys
import pandas as pd
import numpy as np
from pathlib import Path

# Windows: la consola por defecto (cp1252) no puede imprimir símbolos como →/✓.
# Forzar UTF-8 en stdout evita UnicodeEncodeError al ejecutar el pipeline.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

# ── Rutas ──────────────────────────────────────────────────────────────────
ROOT        = Path(__file__).resolve().parents[2]
GAMA_OUT    = ROOT / "gama" / "outputs"
RESULTS_DIR = ROOT / "analysis" / "results"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

# ── Archivos de entrada por escenario ─────────────────────────────────────
# E0: baseline sin peaje. EB: peaje por franja horaria. Un CSV fijo por escenario;
# si un valor es None, se busca por patrón glob {escenario}_run*_metricas.csv.
ARCHIVOS_ESCENARIO = {
    "E0": ["E0_metricas.csv"],
    "EB": ["EB_metricas.csv"],
}

# ── Fracción de buses en la flota (calibrado DMQ 2023) ────────────────────
# Usado para corregir directo_nse_bajo en el análisis de equidad.
# Buses siempre toman RUTA_DIRECTA y siempre cuentan como NSE_BAJO,
# lo que infla artificialmente ese contador. Esta fracción se aplica
# como corrección estimada; documentar en el paper (§ Equidad NSE).
NB_BUSES_DEFAULT = 30
NB_TOTAL_DEFAULT = 300
BUS_FRACTION     = NB_BUSES_DEFAULT / NB_TOTAL_DEFAULT   # 0.10

# ── Columnas reales exportadas por GAMA ───────────────────────────────────
# Orden exacto del CSV (header incluido en el archivo → pd.read_csv normal).
# Las columnas NSE desagregadas solo existen en EB; en E0 pueden faltar.
COLUMNAS_CORE = [
    "escenario", "minuto", "hora", "es_hora_pico",
    "nb_conductores",
    "velocidad_media_kmh",
    "pct_ruta_directa", "pct_reroutean", "pct_metro",
    "modal_shift_acum",
    "recaudacion_acum_usd",
    "nb_restringidos_placa",
]
COLUMNAS_NSE = [
    "directo_nse_alto",  "directo_nse_medio",  "directo_nse_bajo",
    "metro_nse_alto",    "metro_nse_medio",     "metro_nse_bajo",
    "rerouta_nse_alto",  "rerouta_nse_medio",   "rerouta_nse_bajo",
]


# ─────────────────────────────────────────────────────────────────────────────
def cargar_runs(escenario: str) -> pd.DataFrame:
    """
    Carga uno o varios CSV de un escenario y los concatena.
    Archivo fijo por escenario (E0_metricas.csv / EB_metricas.csv); admite
    glob {escenario}_run*_metricas.csv si el escenario no tiene archivo fijo.
    """
    if ARCHIVOS_ESCENARIO.get(escenario):
        archivos = [GAMA_OUT / f for f in ARCHIVOS_ESCENARIO[escenario]
                    if (GAMA_OUT / f).exists()]
    else:
        archivos = sorted(GAMA_OUT.glob(f"{escenario}_run*_metricas.csv"))

    if not archivos:
        print(f"[AVISO] No se encontraron archivos para '{escenario}'")
        print(f"        Buscado en: {GAMA_OUT}")
        print(f"        Generando datos sintéticos para prueba del pipeline...")
        return generar_datos_ejemplo(escenario)

    dfs = []
    for archivo in archivos:
        try:
            df = pd.read_csv(archivo)          # el CSV ya trae header propio
            df["archivo_fuente"] = archivo.name
            dfs.append(df)
            print(f"  [OK] {archivo.name} — {len(df)} registros, "
                  f"{len(df.columns)} columnas")
        except Exception as e:
            print(f"  [ERROR] {archivo.name}: {e}")

    return pd.concat(dfs, ignore_index=True) if dfs else generar_datos_ejemplo(escenario)


# ─────────────────────────────────────────────────────────────────────────────
def rellenar_columnas_faltantes(df: pd.DataFrame, escenario: str) -> pd.DataFrame:
    """
    Paso 2: rellena columnas que pueden estar ausentes según el escenario.

    E0 no tiene peaje → recaudacion_acum_usd = 0.
    Si la restricción de placa no se exportó → nb_restringidos_placa = 0.
    Columnas NSE desagregadas opcionales → 0 si ausentes.
    """
    # Columnas que E0 puede no tener (peaje no activo)
    columnas_cero_float = ["recaudacion_acum_usd"]
    columnas_cero_int   = ["nb_restringidos_placa", "modal_shift_acum"]

    for col in columnas_cero_float:
        if col not in df.columns:
            df[col] = 0.0
            print(f"  [RELLENO] '{col}' no encontrada en {escenario} → 0.0")

    for col in columnas_cero_int:
        if col not in df.columns:
            df[col] = 0
            print(f"  [RELLENO] '{col}' no encontrada en {escenario} → 0")

    # Columnas NSE desagregadas
    for col in COLUMNAS_NSE:
        if col not in df.columns:
            df[col] = 0

    return df


# ─────────────────────────────────────────────────────────────────────────────
def corregir_equidad_buses(df: pd.DataFrame) -> pd.DataFrame:
    """
    Paso 3: filtra la contribución de buses del análisis de equidad NSE.

    Buses siempre toman RUTA_DIRECTA y se contabilizan como NSE_BAJO.
    Esto infla directo_nse_bajo de forma no representativa (no es una
    decisión libre de modo; es el comportamiento fijo del tipo BUS).

    Corrección estimada:
        bus_count_intervalo ≈ BUS_FRACTION × (directo_nse_bajo
                               + metro_nse_bajo + rerouta_nse_bajo)
    Se asume que toda la contribución bus cae en directo_nse_bajo.

    Se generan columnas *_corr para uso en cálculo Gini (02_compare.py).
    Las columnas originales se conservan intactas para trazabilidad.
    """
    total_bajo = (df["directo_nse_bajo"]
                + df["metro_nse_bajo"]
                + df["rerouta_nse_bajo"])

    # Estimación lineal de decisiones de buses en cada intervalo
    bus_directo_est = (total_bajo * BUS_FRACTION).round().astype(int)

    df["directo_nse_bajo_corr"] = (df["directo_nse_bajo"] - bus_directo_est).clip(lower=0)
    df["metro_nse_bajo_corr"]   = df["metro_nse_bajo"]      # buses no van al metro
    df["rerouta_nse_bajo_corr"] = df["rerouta_nse_bajo"]    # buses no reroutean

    # Fracción corregida: solo agentes con decisión libre de modo
    total_nse_bajo_corr = (df["directo_nse_bajo_corr"]
                         + df["metro_nse_bajo_corr"]
                         + df["rerouta_nse_bajo_corr"])
    df["pct_metro_bajo_corr"] = np.where(
        total_nse_bajo_corr > 0,
        df["metro_nse_bajo_corr"] / total_nse_bajo_corr * 100.0,
        0.0
    )

    return df


# ─────────────────────────────────────────────────────────────────────────────
def agregar_columnas_derivadas(df: pd.DataFrame) -> pd.DataFrame:
    """
    Paso 4: deriva las columnas de flujo que los scripts 02/03 esperan pero que
    GAMA NO exporta directamente. El CSV no tiene un contador de "vehículos de
    paso"; se aproxima a partir de los contadores de decisión por NSE:

      flujo_poligono : decisiones de RUTA_DIRECTA por intervalo (paso por la zona).
      flujo_externo  : decisiones de REROUTEAR por intervalo (desplazamiento a
                       vías periféricas — proxy de desplazamiento periférico).
      pct_pagan      : en EB, la cuota modal de ruta directa equivale a quienes
                       pagan el peaje en hora pico; se mapea a pct_ruta_directa.

    Nota metodológica: estos contadores reflejan EVENTOS DE DECISIÓN de los
    agentes que deliberaron en el intervalo (no el padrón completo de la flota),
    por lo que deben leerse como proxies de flujo, no como conteos absolutos.
    """
    df["flujo_poligono"] = (df["directo_nse_alto"]
                          + df["directo_nse_medio"]
                          + df["directo_nse_bajo"])
    df["flujo_externo"]  = (df["rerouta_nse_alto"]
                          + df["rerouta_nse_medio"]
                          + df["rerouta_nse_bajo"])
    df["pct_pagan"] = df["pct_ruta_directa"]
    return df


# ─────────────────────────────────────────────────────────────────────────────
def limpiar_dataframe(df: pd.DataFrame, escenario: str) -> pd.DataFrame:
    """
    Tipado, columnas calculadas y limpieza general.
    """
    # Rellenar columnas ausentes antes de cualquier operación
    df = rellenar_columnas_faltantes(df, escenario)

    # Tipos numéricos
    cols_float = [
        "velocidad_media_kmh", "pct_ruta_directa", "pct_reroutean",
        "pct_metro", "recaudacion_acum_usd",
    ]
    cols_int = [
        "minuto", "nb_conductores", "modal_shift_acum",
        "nb_restringidos_placa",
    ] + COLUMNAS_NSE

    for col in cols_float:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    for col in cols_int:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0).astype(int)

    # Booleano es_hora_pico
    if "es_hora_pico" in df.columns:
        df["es_hora_pico"] = (df["es_hora_pico"]
                              .astype(str).str.lower()
                              .isin(["true", "1", "yes"]))

    # Hora decimal para gráficas
    df["hora_decimal"] = df["minuto"] / 60.0

    # Etiqueta de escenario normalizada
    df["escenario"] = escenario

    # Corrección de equidad NSE (elimina contribución de buses)
    df = corregir_equidad_buses(df)

    # Columnas de flujo derivadas que consumen 02/03 (GAMA no las exporta)
    df = agregar_columnas_derivadas(df)

    # Eliminar filas con datos críticos faltantes
    df = df.dropna(subset=["minuto", "velocidad_media_kmh"])

    return df


# ─────────────────────────────────────────────────────────────────────────────
def calcular_estadisticas_por_run(df: pd.DataFrame) -> pd.DataFrame:
    """
    Media y std de métricas clave agrupando por escenario + minuto.
    Para intervalos de confianza 95 % en el paper.
    """
    metricas = [
        "velocidad_media_kmh",
        "pct_ruta_directa", "pct_reroutean", "pct_metro",
        "modal_shift_acum", "recaudacion_acum_usd",
        "directo_nse_bajo_corr", "pct_metro_bajo_corr",
    ]
    agg = {col: ["mean", "std", "min", "max"]
           for col in metricas if col in df.columns}

    resumen = (df.groupby(["escenario", "minuto", "es_hora_pico"])
                 .agg(agg))
    resumen.columns = ["_".join(c).strip() for c in resumen.columns]
    return resumen.reset_index()


# ─────────────────────────────────────────────────────────────────────────────
def generar_datos_ejemplo(escenario: str) -> pd.DataFrame:
    """
    Datos sintéticos para probar el pipeline sin simulación GAMA.
    Calibrados con datos AMT y benchmark Londres 2003.
    """
    np.random.seed(42 if escenario == "E0" else 99)
    minutos = list(range(360, 1320, 15))

    params = {
        "E0":     dict(flujo=320, vel=16.0, metro=5.0,  recaud=0.0),
        "EB":     dict(flujo=230, vel=19.5, metro=18.0, recaud=460.0),
    }.get(escenario, dict(flujo=300, vel=17.0, metro=8.0, recaud=0.0))

    registros = []
    for minuto in minutos:
        pico = (420 <= minuto <= 600) or (1020 <= minuto <= 1200)
        mult = 1.3 if pico else 0.8
        vel  = params["vel"] * (0.75 if pico else 1.1) + np.random.normal(0, 1.5)
        metro = params["metro"] * (1.4 if pico else 0.7) + np.random.normal(0, 2)
        metro = float(np.clip(metro, 0, 100))
        rerouta = (15.0 if escenario == "EB" and pico else 3.0) + np.random.normal(0, 2)
        rerouta = float(max(0.0, rerouta))
        directo = max(0.0, 100.0 - metro - rerouta)
        nb = int(params["flujo"] * mult + np.random.normal(0, 20))
        hh, mm = divmod(minuto, 60)

        # NSE sintético (proporcional a distribución DMQ)
        base_bajo = int(nb * 0.40)
        registros.append({
            "escenario": escenario,
            "minuto": minuto,
            "hora": f"{hh:02d}:{mm:02d}",
            "es_hora_pico": pico,
            "nb_conductores": nb,
            "velocidad_media_kmh": round(float(np.clip(vel, 8, 50)), 2),
            "pct_ruta_directa": round(directo, 2),
            "pct_reroutean": round(rerouta, 2),
            "pct_metro": round(metro, 2),
            "modal_shift_acum": int(metro / 100 * nb * 3),
            "recaudacion_acum_usd": round(params["recaud"] * mult, 2) if pico else 0.0,
            "nb_restringidos_placa": int(nb * 0.20),
            "directo_nse_alto":  int(nb * 0.15 * directo / 100),
            "directo_nse_medio": int(nb * 0.45 * directo / 100),
            "directo_nse_bajo":  base_bajo,
            "metro_nse_alto":    int(nb * 0.15 * metro / 100),
            "metro_nse_medio":   int(nb * 0.45 * metro / 100),
            "metro_nse_bajo":    int(nb * 0.40 * metro / 100),
            "rerouta_nse_alto":  int(nb * 0.15 * rerouta / 100),
            "rerouta_nse_medio": int(nb * 0.45 * rerouta / 100),
            "rerouta_nse_bajo":  int(nb * 0.40 * rerouta / 100),
            "archivo_fuente": f"SYNTHETIC_{escenario}",
        })

    return pd.DataFrame(registros)


# ─────────────────────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("  Procesamiento de resultados GAMA — SMA Quito  v2")
    print("=" * 60)
    print(f"  BUS_FRACTION para corrección NSE: {BUS_FRACTION:.2f}  "
          f"({NB_BUSES_DEFAULT} buses / {NB_TOTAL_DEFAULT} total)")

    resultados = {}

    for escenario in ["E0", "EB"]:
        print(f"\n[{escenario}] Cargando datos...")
        df_raw    = cargar_runs(escenario)
        df_limpio = limpiar_dataframe(df_raw, escenario)
        resultados[escenario] = df_limpio

        ruta = RESULTS_DIR / f"{escenario}_processed.csv"
        df_limpio.to_csv(ruta, index=False)
        print(f"  → {ruta}")
        print(f"     Filas: {len(df_limpio)} | Columnas: {len(df_limpio.columns)}")
        hora_ini = df_limpio["hora"].iloc[0]  if "hora" in df_limpio.columns else "?"
        hora_fin = df_limpio["hora"].iloc[-1] if "hora" in df_limpio.columns else "?"
        print(f"     Rango horario: {hora_ini} – {hora_fin}")
        n_corr = (df_limpio["directo_nse_bajo"]
                - df_limpio["directo_nse_bajo_corr"]).sum()
        print(f"     Decisiones bus eliminadas del análisis NSE: {n_corr}")

    # Dataset combinado
    df_combined = pd.concat(resultados.values(), ignore_index=True)
    ruta_comb = RESULTS_DIR / "combined.csv"
    df_combined.to_csv(ruta_comb, index=False)
    print(f"\n[OK] Dataset combinado: {ruta_comb} ({len(df_combined)} filas)")

    # Resumen estadístico
    resumen = calcular_estadisticas_por_run(df_combined)
    ruta_res = RESULTS_DIR / "resumen_estadistico.csv"
    resumen.to_csv(ruta_res, index=False)
    print(f"[OK] Resumen estadístico: {ruta_res}")

    print("\n[DONE] Pipeline 01 completado. Ejecutar 02_compare_scenarios.py")
    print("\n  NOTA: Para el cálculo Δ Gini modal usar columnas *_corr,")
    print("  no los contadores NSE originales (buses incluidos en _bajo).")


if __name__ == "__main__":
    main()