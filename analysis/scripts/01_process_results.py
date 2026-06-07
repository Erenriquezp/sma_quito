#!/usr/bin/env python3
"""
01_process_results.py
─────────────────────────────────────────────────────────────────────────────
Lee los CSV exportados por GAMA Platform y los normaliza en un DataFrame
limpio y estandarizado, listo para análisis comparativo.

Uso:
    python 01_process_results.py

Entradas:  ../../gama/outputs/E0_run*_metricas.csv
           ../../gama/outputs/EB_run*_metricas.csv
Salidas:   ../results/E0_processed.csv
           ../results/EB_processed.csv
           ../results/combined.csv

Autores: Equipo SMA Quito — UCE Sistemas Colaborativos 2026
─────────────────────────────────────────────────────────────────────────────
"""

import pandas as pd
import numpy as np
from pathlib import Path
import sys

# ── Rutas ──────────────────────────────────────────────────────────────────
ROOT        = Path(__file__).resolve().parents[2]
GAMA_OUT    = ROOT / "gama" / "outputs"
RESULTS_DIR = ROOT / "analysis" / "results"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

# ── Columnas esperadas del CSV de GAMA ────────────────────────────────────
COLUMNS = [
    "run_id", "escenario", "minuto", "hora_legible",
    "es_hora_pico",
    "flujo_poligono", "flujo_externo",
    "pct_pagan", "pct_reroutean", "pct_metro",
    "velocidad_media_kmh",
    "recaudacion_acum_usd",
    "count_restringidos_placa",
]


def cargar_runs(escenario: str) -> pd.DataFrame:
    """
    Carga todos los archivos CSV de un escenario (múltiples réplicas)
    y los concatena en un único DataFrame.
    """
    patron = f"{escenario}_run*_metricas.csv"
    archivos = sorted(GAMA_OUT.glob(patron))

    if not archivos:
        print(f"[AVISO] No se encontraron archivos para escenario {escenario}")
        print(f"        Buscado en: {GAMA_OUT}")
        print(f"        Patrón:     {patron}")
        print(f"        Generando datos de ejemplo para prueba del pipeline...")
        return generar_datos_ejemplo(escenario)

    dfs = []
    for archivo in archivos:
        try:
            df = pd.read_csv(archivo, names=COLUMNS, skiprows=1)
            df["archivo_fuente"] = archivo.name
            dfs.append(df)
            print(f"  [OK] {archivo.name} — {len(df)} registros")
        except Exception as e:
            print(f"  [ERROR] {archivo.name}: {e}")

    if not dfs:
        return generar_datos_ejemplo(escenario)

    return pd.concat(dfs, ignore_index=True)


def generar_datos_ejemplo(escenario: str) -> pd.DataFrame:
    """
    Genera datos sintéticos para probar el pipeline de análisis
    antes de tener la simulación GAMA funcionando.
    Basado en valores calibrados con datos AMT y benchmark Londres.
    """
    print(f"  [INFO] Generando datos sintéticos para {escenario}...")
    np.random.seed(42 if escenario == "E0" else 99)

    minutos = list(range(360, 1320, 15))  # 6:00am a 22:00pm, cada 15 min
    n = len(minutos)

    # Parámetros base por escenario
    if escenario == "E0":
        flujo_base = 320
        velocidad_base = 16.0
        pct_metro_base = 5.0
    else:  # EB
        flujo_base = 230   # ~28% reducción (benchmark Londres: 27%)
        velocidad_base = 19.5  # ~22% mejora (benchmark: 20%)
        pct_metro_base = 18.0  # Modal shift significativo

    registros = []
    for i, minuto in enumerate(minutos):
        en_pico = (420 <= minuto <= 600) or (1020 <= minuto <= 1200)

        # Variación realista con ruido gaussiano
        flujo = int(flujo_base * (1.3 if en_pico else 0.8) + np.random.normal(0, 20))
        flujo = max(50, flujo)

        velocidad = velocidad_base * (0.75 if en_pico else 1.1) + np.random.normal(0, 1.5)
        velocidad = max(8.0, min(50.0, velocidad))

        pct_metro = (pct_metro_base * (1.4 if en_pico else 0.7)) + np.random.normal(0, 2)
        pct_metro = max(0.0, min(100.0, pct_metro))

        pct_reroutean = (15.0 if escenario == "EB" and en_pico else 3.0) + np.random.normal(0, 2)
        pct_reroutean = max(0.0, pct_reroutean)

        pct_pagan = max(0.0, 100.0 - pct_metro - pct_reroutean) if escenario == "EB" else 97.0

        recaudacion = (flujo * 2.0 * 0.6) if (escenario == "EB" and en_pico) else 0.0

        horas = minuto // 60
        mins  = minuto % 60
        hora_str = f"{horas:02d}:{mins:02d}"

        registros.append({
            "run_id": 1,
            "escenario": escenario,
            "minuto": minuto,
            "hora_legible": hora_str,
            "es_hora_pico": en_pico,
            "flujo_poligono": flujo,
            "flujo_externo": int(flujo * 0.15),
            "pct_pagan": round(pct_pagan, 2),
            "pct_reroutean": round(pct_reroutean, 2),
            "pct_metro": round(pct_metro, 2),
            "velocidad_media_kmh": round(velocidad, 2),
            "recaudacion_acum_usd": round(recaudacion, 2),
            "count_restringidos_placa": int(flujo * 0.20),
            "archivo_fuente": f"SYNTHETIC_{escenario}",
        })

    return pd.DataFrame(registros)


def limpiar_dataframe(df: pd.DataFrame, escenario: str) -> pd.DataFrame:
    """
    Limpieza y tipado del DataFrame.
    """
    # Tipos numéricos
    numericas = [
        "minuto", "flujo_poligono", "flujo_externo",
        "pct_pagan", "pct_reroutean", "pct_metro",
        "velocidad_media_kmh", "recaudacion_acum_usd",
        "count_restringidos_placa",
    ]
    for col in numericas:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Booleano
    if "es_hora_pico" in df.columns:
        df["es_hora_pico"] = df["es_hora_pico"].astype(str).str.lower().isin(["true", "1", "yes"])

    # Columna calculada: reducción vehicular vs. capacidad base
    # Solo relevante para comparación E0 vs EB; se hace en script 02
    df["escenario"] = escenario

    # Agregar hora decimal para facilitar gráficas
    df["hora_decimal"] = df["minuto"] / 60.0

    # Eliminar filas con datos faltantes críticos
    df = df.dropna(subset=["minuto", "flujo_poligono"])

    return df


def calcular_estadisticas_por_run(df: pd.DataFrame) -> pd.DataFrame:
    """
    Calcula media y std de métricas clave agrupando por escenario y minuto.
    Necesario para el análisis estadístico del paper (intervalo de confianza 95%).
    """
    metricas_clave = [
        "flujo_poligono", "flujo_externo", "velocidad_media_kmh",
        "pct_pagan", "pct_reroutean", "pct_metro",
    ]

    agg_dict = {col: ["mean", "std", "min", "max"] for col in metricas_clave}
    agg_dict["recaudacion_acum_usd"] = ["mean", "std"]

    resumen = df.groupby(["escenario", "minuto", "es_hora_pico"]).agg(agg_dict)
    resumen.columns = ["_".join(col).strip() for col in resumen.columns]
    resumen = resumen.reset_index()

    return resumen


def main():
    print("=" * 60)
    print("  Procesamiento de resultados GAMA — SMA Quito")
    print("=" * 60)

    resultados = {}

    for escenario in ["E0", "EB"]:
        print(f"\n[{escenario}] Cargando datos...")
        df_raw  = cargar_runs(escenario)
        df_limpio = limpiar_dataframe(df_raw, escenario)
        resultados[escenario] = df_limpio

        # Guardar CSV procesado
        ruta_salida = RESULTS_DIR / f"{escenario}_processed.csv"
        df_limpio.to_csv(ruta_salida, index=False)
        print(f"  → Guardado: {ruta_salida}")
        print(f"     Filas: {len(df_limpio)} | Columnas: {len(df_limpio.columns)}")
        print(f"     Rango de horas: {df_limpio['hora_legible'].iloc[0]} – {df_limpio['hora_legible'].iloc[-1]}")

    # Dataset combinado para comparación directa
    df_combined = pd.concat(resultados.values(), ignore_index=True)
    ruta_combined = RESULTS_DIR / "combined.csv"
    df_combined.to_csv(ruta_combined, index=False)
    print(f"\n[OK] Dataset combinado: {ruta_combined} ({len(df_combined)} filas)")

    # Estadísticas de resumen
    resumen = calcular_estadisticas_por_run(df_combined)
    ruta_resumen = RESULTS_DIR / "resumen_estadistico.csv"
    resumen.to_csv(ruta_resumen, index=False)
    print(f"[OK] Resumen estadístico: {ruta_resumen}")

    print("\n[DONE] Pipeline 01 completado. Ejecutar 02_compare_scenarios.py")


if __name__ == "__main__":
    main()
