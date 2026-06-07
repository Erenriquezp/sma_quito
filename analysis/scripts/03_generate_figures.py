#!/usr/bin/env python3
"""
03_generate_figures.py
─────────────────────────────────────────────────────────────────────────────
Genera las figuras para el paper académico (Overleaf).
Produce PNGs en alta resolución (300 DPI) y PDFs para LaTeX.

Figuras generadas:
  Fig 1: Flujo vehicular E0 vs EB a lo largo del día (serie temporal)
  Fig 2: Velocidad media E0 vs EB (serie temporal)
  Fig 3: Distribución de decisiones BDI (gráfica de barras apiladas)
  Fig 4: Modal shift comparativo E0 vs EB (barras por franja horaria)
  Fig 5: Benchmark — comparación con London Congestion Charge

Uso:
    python 03_generate_figures.py
    (Requiere haber ejecutado 01 y 02 antes)

Autores: Equipo SMA Quito — UCE Sistemas Colaborativos 2026
─────────────────────────────────────────────────────────────────────────────
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path

# ── Configuración global de matplotlib para el paper ──────────────────────
plt.rcParams.update({
    "font.family":      "serif",
    "font.size":        11,
    "axes.labelsize":   12,
    "axes.titlesize":   13,
    "axes.titleweight": "bold",
    "legend.fontsize":  10,
    "xtick.labelsize":  10,
    "ytick.labelsize":  10,
    "figure.dpi":       150,
    "savefig.dpi":      300,
    "savefig.bbox":     "tight",
    "axes.spines.top":  False,
    "axes.spines.right":False,
    "grid.alpha":       0.3,
})

# ── Paleta de colores del paper ────────────────────────────────────────────
COLOR_E0   = "#2E6DA4"  # Azul UCE para baseline
COLOR_EB   = "#E85D04"  # Naranja para escenario peaje
COLOR_PICO = "#FFF3CD"  # Fondo suave para franja pico
COLOR_METRO= "#1A7F64"  # Verde para modal shift Metro

# ── Rutas ──────────────────────────────────────────────────────────────────
ROOT        = Path(__file__).resolve().parents[2]
RESULTS_DIR = ROOT / "analysis" / "results"
FIGURES_DIR = ROOT / "analysis" / "figures"
FIGURES_DIR.mkdir(parents=True, exist_ok=True)


def cargar_datos() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    ruta = RESULTS_DIR / "combined.csv"
    if not ruta.exists():
        raise FileNotFoundError(f"Ejecutar 01_process_results.py primero. No encontrado: {ruta}")

    df = pd.read_csv(ruta)
    e0 = df[df["escenario"] == "E0"].copy()
    eb = df[df["escenario"] == "EB"].copy()
    return df, e0, eb


def agregar_por_hora(df: pd.DataFrame) -> pd.DataFrame:
    """Agrupa datos por minuto para graficar serie temporal."""
    return df.groupby("minuto").agg({
        "flujo_poligono":    ["mean", "std"],
        "velocidad_media_kmh": ["mean", "std"],
        "pct_metro":         ["mean", "std"],
        "pct_reroutean":     ["mean", "std"],
        "pct_pagan":         ["mean", "std"],
        "flujo_externo":     ["mean", "std"],
    }).reset_index()


def agregar_franjas(df: pd.DataFrame) -> pd.DataFrame:
    """Agrupa por franja horaria para gráficas de barras."""
    def franja(minuto):
        if   360 <= minuto < 420:  return "06–07h"
        elif 420 <= minuto < 600:  return "07–10h\n(pico matutino)"
        elif 600 <= minuto < 720:  return "10–12h"
        elif 720 <= minuto < 1020: return "12–17h"
        elif 1020 <= minuto < 1200: return "17–20h\n(pico vespertino)"
        else:                       return "20–22h"
    df = df.copy()
    df["franja"] = df["minuto"].apply(franja)
    return df.groupby("franja")[
        ["flujo_poligono", "velocidad_media_kmh", "pct_metro", "pct_reroutean"]
    ].mean().reset_index()


def sombrear_pico(ax):
    """Añade bandas de color para las franjas pico en gráficas de serie temporal."""
    ax.axvspan(420 / 60, 600 / 60, alpha=0.12, color=COLOR_EB, label="Hora pico")
    ax.axvspan(1020 / 60, 1200 / 60, alpha=0.12, color=COLOR_EB)


def hora_ticks(ax):
    """Configura el eje X con horas legibles (06:00–22:00)."""
    horas = list(range(6, 23))
    ax.set_xticks([h for h in horas])
    ax.set_xticklabels([f"{h:02d}:00" for h in horas], rotation=45, ha="right")
    ax.set_xlabel("Hora del día")


def guardar(fig, nombre: str):
    for ext in ["png", "pdf"]:
        ruta = FIGURES_DIR / f"{nombre}.{ext}"
        fig.savefig(ruta)
    print(f"  [OK] {nombre}.png / .pdf → {FIGURES_DIR}")
    plt.close(fig)


# ── Figura 1: Flujo vehicular E0 vs EB ────────────────────────────────────
def fig1_flujo(e0_agg, eb_agg):
    fig, ax = plt.subplots(figsize=(9, 4.5))

    x_e0 = e0_agg["minuto"] / 60
    x_eb = eb_agg["minuto"] / 60

    ax.plot(x_e0, e0_agg[("flujo_poligono", "mean")],
            color=COLOR_E0, lw=2, label="E0 — Baseline (sin peaje)")
    ax.fill_between(x_e0,
        e0_agg[("flujo_poligono", "mean")] - e0_agg[("flujo_poligono", "std")],
        e0_agg[("flujo_poligono", "mean")] + e0_agg[("flujo_poligono", "std")],
        alpha=0.15, color=COLOR_E0)

    ax.plot(x_eb, eb_agg[("flujo_poligono", "mean")],
            color=COLOR_EB, lw=2, linestyle="--", label="EB — Peaje por franja horaria")
    ax.fill_between(x_eb,
        eb_agg[("flujo_poligono", "mean")] - eb_agg[("flujo_poligono", "std")],
        eb_agg[("flujo_poligono", "mean")] + eb_agg[("flujo_poligono", "std")],
        alpha=0.15, color=COLOR_EB)

    sombrear_pico(ax)
    hora_ticks(ax)
    ax.set_ylabel("Vehículos en el polígono")
    ax.set_title("Fig. 1 — Flujo vehicular en el sector La Carolina: E0 vs EB")
    ax.legend(loc="upper right")
    ax.grid(True, axis="y")

    # Anotación: reducción en hora pico
    pico_e0 = e0_agg[(e0_agg["minuto"] >= 420) & (e0_agg["minuto"] <= 600)][("flujo_poligono", "mean")].mean()
    pico_eb = eb_agg[(eb_agg["minuto"] >= 420) & (eb_agg["minuto"] <= 600)][("flujo_poligono", "mean")].mean()
    if pico_e0 > 0:
        reduccion = abs(pico_eb - pico_e0) / pico_e0 * 100
        ax.annotate(f"−{reduccion:.0f}% en hora pico",
                    xy=(8.5, (pico_e0 + pico_eb) / 2),
                    fontsize=10, color=COLOR_EB,
                    arrowprops=dict(arrowstyle="<->", color=COLOR_EB))

    guardar(fig, "fig1_flujo_vehicular")


# ── Figura 2: Velocidad media E0 vs EB ────────────────────────────────────
def fig2_velocidad(e0_agg, eb_agg):
    fig, ax = plt.subplots(figsize=(9, 4.5))

    x_e0 = e0_agg["minuto"] / 60
    x_eb = eb_agg["minuto"] / 60

    ax.plot(x_e0, e0_agg[("velocidad_media_kmh", "mean")],
            color=COLOR_E0, lw=2, label="E0 — Baseline")
    ax.plot(x_eb, eb_agg[("velocidad_media_kmh", "mean")],
            color=COLOR_EB, lw=2, linestyle="--", label="EB — Peaje")

    # Línea de referencia: benchmark Londres +20%
    v_base = e0_agg[("velocidad_media_kmh", "mean")].mean()
    ax.axhline(y=v_base * 1.20, color="gray", linestyle=":", lw=1.5,
               label=f"Meta benchmark: +20% ({v_base * 1.20:.1f} km/h)")

    sombrear_pico(ax)
    hora_ticks(ax)
    ax.set_ylabel("Velocidad media (km/h)")
    ax.set_title("Fig. 2 — Velocidad media en el polígono La Carolina: E0 vs EB")
    ax.legend(loc="lower right")
    ax.grid(True, axis="y")

    guardar(fig, "fig2_velocidad_media")


# ── Figura 3: Distribución de decisiones BDI ─────────────────────────────
def fig3_decisiones(e0: pd.DataFrame, eb: pd.DataFrame):
    fig, axes = plt.subplots(1, 2, figsize=(10, 5))

    def pie_decisiones(ax, df, titulo):
        pagan     = df["pct_pagan"].mean()
        reroutean = df["pct_reroutean"].mean()
        metro     = df["pct_metro"].mean()
        # Ajustar para que sumen 100%
        total = pagan + reroutean + metro
        if total > 0:
            pagan, reroutean, metro = pagan/total*100, reroutean/total*100, metro/total*100

        labels = ["Pagan peaje\n(ruta directa)", "Reroutan\n(vía periférica)", "→ Metro"]
        sizes  = [pagan, reroutean, metro]
        colors = [COLOR_E0, "#F4A261", COLOR_METRO]
        explode = (0, 0.05, 0.05)

        wedges, texts, autotexts = ax.pie(
            sizes, labels=labels, colors=colors, explode=explode,
            autopct="%1.1f%%", startangle=90, pctdistance=0.75
        )
        for at in autotexts:
            at.set_fontsize(10)
        ax.set_title(titulo, fontweight="bold")

    pie_decisiones(axes[0], e0, "E0 — Baseline\n(sin peaje)")
    pie_decisiones(axes[1], eb, "EB — Peaje franja horaria\n($2.00 USD en pico)")

    fig.suptitle("Fig. 3 — Distribución de decisiones de los agentes BDI",
                 fontsize=13, fontweight="bold", y=1.02)
    guardar(fig, "fig3_decisiones_bdi")


# ── Figura 4: Modal shift por franja horaria ─────────────────────────────
def fig4_modal_shift(e0: pd.DataFrame, eb: pd.DataFrame):
    fig, ax = plt.subplots(figsize=(10, 5))

    e0_fr = agregar_franjas(e0)
    eb_fr = agregar_franjas(eb)

    franjas = e0_fr["franja"].tolist()
    x = np.arange(len(franjas))
    ancho = 0.35

    b1 = ax.bar(x - ancho/2, e0_fr["pct_metro"], ancho,
                color=COLOR_E0, alpha=0.85, label="E0 — Baseline", edgecolor="white")
    b2 = ax.bar(x + ancho/2, eb_fr["pct_metro"], ancho,
                color=COLOR_METRO, alpha=0.85, label="EB — Peaje", edgecolor="white")

    ax.set_xticks(x)
    ax.set_xticklabels(franjas, ha="center")
    ax.set_xlabel("Franja horaria")
    ax.set_ylabel("Modal shift → Metro (%)")
    ax.set_title("Fig. 4 — Modal shift hacia el Metro de Quito por franja horaria: E0 vs EB")
    ax.legend()
    ax.grid(True, axis="y")

    # Etiquetas de valor
    for bar in [b1, b2]:
        for rect in bar:
            h = rect.get_height()
            ax.annotate(f"{h:.1f}%",
                xy=(rect.get_x() + rect.get_width() / 2, h),
                xytext=(0, 3), textcoords="offset points",
                ha="center", va="bottom", fontsize=9)

    guardar(fig, "fig4_modal_shift")


# ── Figura 5: Comparación con benchmark Londres ───────────────────────────
def fig5_benchmark(e0: pd.DataFrame, eb: pd.DataFrame):
    fig, ax = plt.subplots(figsize=(9, 5))

    # Calcular métricas del modelo
    pico_e0_flujo = e0[e0["es_hora_pico"] == True]["flujo_poligono"].mean()
    pico_eb_flujo = eb[eb["es_hora_pico"] == True]["flujo_poligono"].mean()
    red_vehicular = abs(pico_eb_flujo - pico_e0_flujo) / pico_e0_flujo * 100 if pico_e0_flujo > 0 else 0

    pico_e0_vel = e0[e0["es_hora_pico"] == True]["velocidad_media_kmh"].mean()
    pico_eb_vel = eb[eb["es_hora_pico"] == True]["velocidad_media_kmh"].mean()
    mejora_vel = (pico_eb_vel - pico_e0_vel) / pico_e0_vel * 100 if pico_e0_vel > 0 else 0

    modal_eb = eb[eb["es_hora_pico"] == True]["pct_metro"].mean()

    indicadores = [
        "Reducción vehicular\n(hora pico, %)",
        "Mejora velocidad\n(hora pico, %)",
        "Modal shift\ntransporte público (%)",
    ]
    valores_londres = [27.0, 20.0, 12.0]
    valores_modelo  = [red_vehicular, mejora_vel, modal_eb]
    meta_quito      = [20.0, 0.0, 5.0]

    x = np.arange(len(indicadores))
    ancho = 0.28

    b1 = ax.bar(x - ancho, valores_londres, ancho, label="Londres 2003 (empírico)",
                color="#B5C4B1", edgecolor="gray")
    b2 = ax.bar(x,         valores_modelo,  ancho, label="Modelo SMA Quito (EB)",
                color=COLOR_EB, alpha=0.85, edgecolor=COLOR_EB)

    # Línea de meta
    for i, meta in enumerate(meta_quito):
        if meta > 0:
            ax.plot([x[i] - ancho * 1.5, x[i] + ancho * 1.5], [meta, meta],
                    color="black", linestyle="--", lw=1.5, zorder=5)
            ax.annotate(f"Meta: {meta}%",
                        xy=(x[i] + ancho * 1.5, meta), xytext=(5, 0),
                        textcoords="offset points", va="center", fontsize=9)

    ax.set_xticks(x)
    ax.set_xticklabels(indicadores, ha="center")
    ax.set_ylabel("Porcentaje (%)")
    ax.set_title("Fig. 5 — Comparación modelo SMA Quito vs. London Congestion Charge (2003)")
    ax.legend(loc="upper right")
    ax.grid(True, axis="y")

    guardar(fig, "fig5_benchmark_londres")


def main():
    print("=" * 60)
    print("  Generación de figuras para el paper — SMA Quito")
    print("=" * 60)

    df, e0, eb = cargar_datos()

    e0_agg = agregar_por_hora(e0)
    eb_agg = agregar_por_hora(eb)

    print("\nGenerando figuras...")
    fig1_flujo(e0_agg, eb_agg)
    fig2_velocidad(e0_agg, eb_agg)
    fig3_decisiones(e0, eb)
    fig4_modal_shift(e0, eb)
    fig5_benchmark(e0, eb)

    print(f"\n[DONE] 5 figuras guardadas en: {FIGURES_DIR}")
    print("       Formatos: .png (para visualización) y .pdf (para Overleaf)")
    print("\nPara incluir en Overleaf:")
    print("  \\includegraphics[width=\\linewidth]{figures/fig1_flujo_vehicular}")


if __name__ == "__main__":
    main()
