#!/usr/bin/env python3
"""
02_compare_scenarios.py
─────────────────────────────────────────────────────────────────────────────
Genera la tabla comparativa E0 vs EB con las métricas clave del paper.
Incluye benchmark contra London Congestion Charge (2003).

Uso:
    python 02_compare_scenarios.py
    (Requiere haber ejecutado 01_process_results.py antes)

Entrada:  ../results/combined.csv
Salida:   ../results/tabla_comparativa.csv
          ../results/tabla_benchmark.csv
          (Imprime tabla en consola lista para Overleaf)

Autores: Equipo SMA Quito — UCE Sistemas Colaborativos 2026
─────────────────────────────────────────────────────────────────────────────
"""

import sys
import pandas as pd
import numpy as np
from pathlib import Path
from scipy import stats

# Windows: forzar UTF-8 en stdout (símbolos →/✓/± rompen la consola cp1252).
try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

# ── Rutas ──────────────────────────────────────────────────────────────────
ROOT        = Path(__file__).resolve().parents[2]
RESULTS_DIR = ROOT / "analysis" / "results"

# ── Datos del benchmark London Congestion Charge (fuente: J. Urban Econ. 2020)
BENCHMARK_LONDRES = {
    "reduccion_vehicular_pct":    27.0,   # −27% autos en 6 meses
    "mejora_velocidad_pct":       20.0,   # +20% velocidad hora pico
    "reduccion_congestion_pct":   30.0,   # −30% congestión año 1
    "modal_shift_pct":            12.0,   # Cambio modal estimado
    "tarifa_inicial_usd":          6.0,   # £5 ≈ $6 USD (2003)
}

# ── Meta del modelo para validar hipótesis ─────────────────────────────────
META_REDUCCION_VEHICULAR = 20.0  # ≥ 20% para validar hipótesis


def cargar_datos() -> tuple[pd.DataFrame, pd.DataFrame]:
    ruta = RESULTS_DIR / "combined.csv"
    if not ruta.exists():
        print("[ERROR] Ejecutar primero 01_process_results.py")
        raise FileNotFoundError(ruta)

    df = pd.read_csv(ruta)
    e0 = df[df["escenario"] == "E0"].copy()
    eb = df[df["escenario"] == "EB"].copy()
    if e0.empty:
        print("[AVISO] 0 filas E0 en combined.csv — ¿corriste 01 con datos reales?")
    return e0, eb


def calcular_metricas_globales(df: pd.DataFrame) -> dict:
    """
    Calcula métricas agregadas para toda la simulación.
    """
    pico    = df[df["es_hora_pico"] == True]
    no_pico = df[df["es_hora_pico"] == False]

    minutos_unicos = sorted(df["minuto"].unique())
    horas_simulacion = len(minutos_unicos) / 4.0 if len(minutos_unicos) > 0 else np.nan

    recaudacion_por_run = df.groupby("archivo_fuente")["recaudacion_acum_usd"].max()
    recaudacion_promedio_total = recaudacion_por_run.mean() if len(recaudacion_por_run) > 0 else np.nan
    recaudacion_promedio_hora = (recaudacion_promedio_total / horas_simulacion
                                 if horas_simulacion > 0 else np.nan)

    return {
        "flujo_promedio_total":          df["flujo_poligono_hora"].mean(),
        "flujo_promedio_pico":           pico["flujo_poligono_hora"].mean() if len(pico) > 0 else np.nan,
        "flujo_promedio_no_pico":        no_pico["flujo_poligono_hora"].mean() if len(no_pico) > 0 else np.nan,
        "velocidad_promedio_total":      df["velocidad_media_kmh"].mean(),
        "velocidad_promedio_pico":       pico["velocidad_media_kmh"].mean() if len(pico) > 0 else np.nan,
        "pct_metro_promedio":            df["pct_metro"].mean(),
        "pct_metro_pico":                pico["pct_metro"].mean() if len(pico) > 0 else np.nan,
        "pct_reroutean_promedio":        df["pct_reroutean"].mean(),
        "flujo_externo_promedio":        df["flujo_externo_hora"].mean(),
        "gini_modal_promedio":           df["gini_modal_metro"].mean() if "gini_modal_metro" in df.columns else np.nan,
        "gini_modal_pico":               pico["gini_modal_metro"].mean() if "gini_modal_metro" in pico.columns and len(pico) > 0 else np.nan,
        "recaudacion_total_promedio":    recaudacion_promedio_total,
        "recaudacion_promedio_hora":     recaudacion_promedio_hora,
    }


def calcular_delta(val_e0: float, val_eb: float, mayor_es_mejor: bool = False) -> dict:
    """
    Calcula la diferencia absoluta y porcentual entre E0 y EB.
    """
    if pd.isna(val_e0) or pd.isna(val_eb) or val_e0 == 0:
        return {"delta_abs": np.nan, "delta_pct": np.nan, "mejora": False}

    delta_abs = val_eb - val_e0
    delta_pct = delta_abs / val_e0 * 100.0
    mejora = (delta_abs > 0) if mayor_es_mejor else (delta_abs < 0)

    return {
        "delta_abs": round(delta_abs, 2),
        "delta_pct": round(delta_pct, 2),
        "mejora": mejora,
    }


def test_significancia(e0: pd.DataFrame, eb: pd.DataFrame, columna: str) -> dict:
    """
    Test t de Student para verificar si la diferencia E0 vs EB es estadísticamente
    significativa. p < 0.05 = diferencia significativa (para el paper).
    """
    s_e0 = e0[columna].dropna()
    s_eb = eb[columna].dropna()

    if len(s_e0) < 3 or len(s_eb) < 3:
        return {"t_stat": np.nan, "p_value": np.nan, "significativo": False}

    t_stat, p_value = stats.ttest_ind(s_e0, s_eb)
    return {
        "t_stat": round(t_stat, 4),
        "p_value": round(p_value, 4),
        "significativo": p_value < 0.05,
    }


def generar_tabla_comparativa(m_e0: dict, m_eb: dict) -> pd.DataFrame:
    """
    Genera la tabla principal de comparación para el paper.
    """
    filas = []

    def fila(metrica, label, val_e0, val_eb, unidad, mayor_es_mejor=False):
        d = calcular_delta(val_e0, val_eb, mayor_es_mejor)
        filas.append({
            "Métrica": label,
            "E0 Baseline": round(val_e0, 2) if not pd.isna(val_e0) else "N/A",
            "EB Peaje": round(val_eb, 2) if not pd.isna(val_eb) else "N/A",
            "Δ Absoluto": d["delta_abs"],
            "Δ %": d["delta_pct"],
            "Unidad": unidad,
            "¿Mejora?": "✓" if d["mejora"] else "✗",
        })

    # Flujo vehicular (menos = mejor para reducir congestión)
    fila("flujo_total", "Flujo promedio en polígono (total)",
         m_e0["flujo_promedio_total"], m_eb["flujo_promedio_total"], "veh/h")

    fila("flujo_pico", "Flujo promedio en polígono (hora pico)",
         m_e0["flujo_promedio_pico"], m_eb["flujo_promedio_pico"], "veh/h")

    fila("flujo_externo", "Desplazamiento periférico (flujo externo)",
         m_e0["flujo_externo_promedio"], m_eb["flujo_externo_promedio"], "veh/h")

    # Velocidad (más = mejor)
    fila("velocidad_total", "Velocidad media en polígono (total)",
         m_e0["velocidad_promedio_total"], m_eb["velocidad_promedio_total"], "km/h",
         mayor_es_mejor=True)

    fila("velocidad_pico", "Velocidad media en polígono (hora pico)",
         m_e0["velocidad_promedio_pico"], m_eb["velocidad_promedio_pico"], "km/h",
         mayor_es_mejor=True)

    # Modal shift (más = mejor, indica absorción por Metro)
    fila("modal_metro_total", "Modal shift → Metro (total)",
         m_e0["pct_metro_promedio"], m_eb["pct_metro_promedio"], "%",
         mayor_es_mejor=True)

    fila("modal_metro_pico", "Modal shift → Metro (hora pico)",
         m_e0["pct_metro_pico"], m_eb["pct_metro_pico"], "%",
         mayor_es_mejor=True)

    fila("gini_modal_promedio", "Equidad socioeconómica — Δ Gini modal (promedio)",
         m_e0["gini_modal_promedio"], m_eb["gini_modal_promedio"], "índice 0–1",
         mayor_es_mejor=False)

    fila("gini_modal_pico", "Equidad socioeconómica — Δ Gini modal (hora pico)",
         m_e0["gini_modal_pico"], m_eb["gini_modal_pico"], "índice 0–1",
         mayor_es_mejor=False)

    fila("recaudacion_por_hora", "Recaudación estimada por hora simulada",
         m_e0["recaudacion_promedio_hora"], m_eb["recaudacion_promedio_hora"], "USD/h",
         mayor_es_mejor=True)

    return pd.DataFrame(filas)


def generar_tabla_benchmark(m_e0: dict, m_eb: dict) -> pd.DataFrame:
    """
    Tabla de comparación directa con el London Congestion Charge.
    Esta es la tabla clave para la sección de Discusión del paper.
    """
    # Calcular reducción vehicular del modelo
    red_vehicular_modelo = abs(calcular_delta(
        m_e0["flujo_promedio_pico"], m_eb["flujo_promedio_pico"]
    )["delta_pct"])

    mejora_velocidad_modelo = calcular_delta(
        m_e0["velocidad_promedio_pico"], m_eb["velocidad_promedio_pico"],
        mayor_es_mejor=True
    )["delta_pct"]

    cumple_hipotesis = (red_vehicular_modelo is not None and
                       not np.isnan(red_vehicular_modelo) and
                       red_vehicular_modelo >= META_REDUCCION_VEHICULAR)

    filas = [
        {
            "Indicador": "Reducción vehicular en zona (hora pico)",
            "Londres 2003": f"−{BENCHMARK_LONDRES['reduccion_vehicular_pct']}%",
            "Meta Quito": f"≥ −{META_REDUCCION_VEHICULAR}%",
            "Modelo (EB vs E0)": f"−{round(red_vehicular_modelo, 1)}%" if not np.isnan(red_vehicular_modelo) else "N/A",
            "¿Cumple?": "SÍ ✓" if cumple_hipotesis else "NO — recalibrar",
        },
        {
            "Indicador": "Mejora de velocidad media (hora pico)",
            "Londres 2003": f"+{BENCHMARK_LONDRES['mejora_velocidad_pct']}%",
            "Meta Quito": "> 0%",
            "Modelo (EB vs E0)": f"{mejora_velocidad_modelo:+.1f}%" if (mejora_velocidad_modelo and not np.isnan(mejora_velocidad_modelo)) else "N/A",
            "¿Cumple?": "SÍ ✓" if (mejora_velocidad_modelo and mejora_velocidad_modelo > 0) else "NO",
        },
        {
            "Indicador": "Modal shift al transporte público",
            "Londres 2003": f"~{BENCHMARK_LONDRES['modal_shift_pct']}% (tube+bus)",
            "Meta Quito": "> 5%",
            "Modelo (EB vs E0)": f"~{round(m_eb['pct_metro_pico'], 1)}% (Metro)",
            "¿Cumple?": "SÍ ✓" if m_eb["pct_metro_pico"] > 5.0 else "NO",
        },
        {
            "Indicador": "Tarifa pico (hora pico)",
            "Londres 2003": f"£5 ≈ ${BENCHMARK_LONDRES['tarifa_inicial_usd']} USD (2003)",
            "Meta Quito": "$2.00–$3.00 USD (propuesto)",
            "Modelo (EB vs E0)": "Auto/SUV $2-3 · Carga $3 · Moto/Bus exentos",
            "¿Cumple?": "—",
        },
    ]

    return pd.DataFrame(filas)


def generar_tabla_tarifa_tipo(eb: pd.DataFrame) -> pd.DataFrame:
    """
    Desglose de la diferenciación tarifaria por tipo de vehículo (solo EB).
    Lee las columnas acumuladas recaud_* / pagos_* (su máximo = total de la corrida)
    y reporta recaudación, nº de pagos y tarifa media efectiva por tipo. Hace
    observable que el peaje discrimina por tipo (Auto/SUV/Carga; Moto/Bus exonerados).
    """
    tipos = [
        ("Auto",  "recaud_auto",  "pagos_auto"),
        ("SUV",   "recaud_suv",   "pagos_suv"),
        ("Carga", "recaud_carga", "pagos_carga"),
    ]
    filas = []
    for nombre, c_recaud, c_pagos in tipos:
        recaud = float(eb[c_recaud].max()) if c_recaud in eb.columns and len(eb) else 0.0
        pagos  = int(eb[c_pagos].max())    if c_pagos in eb.columns and len(eb) else 0
        tarifa_media = round(recaud / pagos, 2) if pagos > 0 else 0.0
        filas.append({
            "Tipo de vehículo":          nombre,
            "Recaudación acum. (USD)":   round(recaud, 2),
            "Nº de pagos":               pagos,
            "Tarifa media efectiva (USD)": tarifa_media,
        })
    filas.append({
        "Tipo de vehículo":          "Moto / Bus",
        "Recaudación acum. (USD)":   0.0,
        "Nº de pagos":               0,
        "Tarifa media efectiva (USD)": 0.0,
    })
    return pd.DataFrame(filas)


def imprimir_tabla_latex(df: pd.DataFrame, titulo: str):
    """
    Imprime la tabla en formato LaTeX para Overleaf.
    Copiar directamente al paper.
    """
    print(f"\n% ── {titulo} ──")
    print("% Generado por 02_compare_scenarios.py — SMA Quito UCE 2026")
    try:
        print(df.to_latex(index=False, escape=False, float_format="{:.2f}".format))
    except (ImportError, ModuleNotFoundError):
        # pandas.to_latex enruta por Styler y requiere jinja2 (dependencia opcional).
        # Fallback: construir el tabular a mano para no bloquear el pipeline.
        cols = list(df.columns)
        print("\\begin{tabular}{" + "l" * len(cols) + "}")
        print("\\hline")
        print(" & ".join(str(c) for c in cols) + " \\\\")
        print("\\hline")
        for _, row in df.iterrows():
            print(" & ".join(str(v) for v in row.values) + " \\\\")
        print("\\hline")
        print("\\end{tabular}")


def main():
    print("=" * 60)
    print("  Comparación E0 vs EB — SMA Quito")
    print("=" * 60)

    e0, eb = cargar_datos()

    print(f"\nRegistros E0: {len(e0)} | EB: {len(eb)}")

    m_e0 = calcular_metricas_globales(e0)
    m_eb = calcular_metricas_globales(eb)

    # ── Tabla comparativa principal ────────────────────────────────────────
    tabla_comp = generar_tabla_comparativa(m_e0, m_eb)
    ruta_comp = RESULTS_DIR / "tabla_comparativa.csv"
    tabla_comp.to_csv(ruta_comp, index=False)
    print(f"\n[OK] Tabla comparativa → {ruta_comp}")
    print(tabla_comp.to_string(index=False))

    # ── Tabla benchmark Londres ────────────────────────────────────────────
    tabla_bench = generar_tabla_benchmark(m_e0, m_eb)
    ruta_bench = RESULTS_DIR / "tabla_benchmark.csv"
    tabla_bench.to_csv(ruta_bench, index=False)
    print(f"\n[OK] Tabla benchmark Londres → {ruta_bench}")
    print(tabla_bench.to_string(index=False))

    # ── Diferenciación tarifaria por tipo de vehículo (EB) ─────────────────
    tabla_tipo = generar_tabla_tarifa_tipo(eb)
    ruta_tipo = RESULTS_DIR / "tabla_tarifa_tipo.csv"
    tabla_tipo.to_csv(ruta_tipo, index=False)
    print(f"\n[OK] Tabla recaudación por tipo de vehículo → {ruta_tipo}")
    print(tabla_tipo.to_string(index=False))
    if tabla_tipo["Recaudación acum. (USD)"].sum() == 0:
        print("  [AVISO] Recaudación por tipo = 0 en todas las filas. Re-correr EB en GAMA")
        print("          con el modelo actualizado para poblar recaud_*/pagos_*.")

    # ── Test de significancia estadística ─────────────────────────────────
    print("\n── Significancia estadística (t-test) ──")
    for col in ["flujo_poligono", "velocidad_media_kmh", "pct_metro"]:
        resultado = test_significancia(e0, eb, col)
        sig = "SIGNIFICATIVO ✓" if resultado["significativo"] else "no significativo"
        print(f"  {col:35s} p={resultado['p_value']}  →  {sig}")

    # ── Veredicto de hipótesis ─────────────────────────────────────────────
    red_veh = abs(calcular_delta(m_e0["flujo_promedio_pico"],
                                  m_eb["flujo_promedio_pico"])["delta_pct"])
    print("\n" + "=" * 60)
    print("  VEREDICTO DE HIPÓTESIS")
    print("=" * 60)
    print(f"  Hipótesis: reducción ≥ {META_REDUCCION_VEHICULAR}%")
    print(f"  Resultado del modelo: {round(red_veh, 1) if not np.isnan(red_veh) else 'N/A'}%")
    if not np.isnan(red_veh):
        if red_veh >= META_REDUCCION_VEHICULAR:
            print(f"  ✓ HIPÓTESIS CONFIRMADA — El modelo respalda la política")
        else:
            print(f"  ✗ HIPÓTESIS NO CONFIRMADA — Recalibrar parámetros")
    print("=" * 60)

    # ── LaTeX para Overleaf ────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("  TABLAS LaTeX PARA OVERLEAF")
    print("=" * 60)
    imprimir_tabla_latex(tabla_bench, "Comparación con London Congestion Charge")

    print("\n[DONE] Pipeline 02 completado. Ejecutar 03_generate_figures.py")


if __name__ == "__main__":
    main()