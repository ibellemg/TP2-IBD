"""
TP2 - Grupo 5 - Gera os graficos a partir do tempos.csv (saida do medir_tempos.py).

Instalacao (uma vez, no venv):  pip install matplotlib
Uso:                            python3 gerar_graficos.py
Opcoes:
  --csv tempos.csv        arquivo de entrada
  --saida graficos        pasta onde os graficos sao salvos
  --paleta ametista       ametista | por_do_sol | jardim  (ou 3 cores: "#hex,#hex,#hex")
  --estatistica media     media | mediana  (valor das barras)
  --formatos pdf,png      pdf para o LaTeX/Overleaf, png para slides e video

Graficos gerados:
  1. comparativo_geral   tempo de cada forma (escala log.) + tempo relativo a forma (a)
  2. por_consulta        um painel por consulta (10 paineis), escala propria em cada um
  3. cold_start          quanto a 1a execucao foi mais lenta que a media das demais
  4. consultas/Qn        um grafico por consulta, bom para slides
"""
import argparse
import csv
import os
import re
import statistics
import textwrap

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

# Paletas conferidas para daltonismo (separacao suficiente entre as 3 cores)
PALETAS = {
    "ametista":   ["#7b5ea7", "#e5a00d", "#2a9d8f"],   # roxo, mostarda, verde-azulado
    "por_do_sol": ["#8e5cc2", "#e8743b", "#2b9fb3"],   # violeta, laranja queimado, azul-petroleo
    "jardim":     ["#c0517a", "#7a6fd0", "#3fa47c"],   # framboesa, lavanda, verde
}
CATEGORIA = {1: "seleção", 2: "seleção", 3: "junção de 2", 4: "junção de 2",
             5: "junção de 2", 6: "junção de 5", 7: "junção de 3", 8: "junção de 4",
             9: "agregação", 10: "agregação"}
TEXTO, TEXTO2, GRADE, EIXO = "#2b2b2b", "#5c5c5c", "#e6e4df", "#9a9893"


def br(v, casas=1):
    """Numero no formato brasileiro (virgula decimal, ponto de milhar)."""
    s = f"{v:,.{casas}f}"
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


def estilo():
    plt.rcParams.update({
        "font.family": "DejaVu Sans", "font.size": 8.5,
        "axes.edgecolor": EIXO, "axes.labelcolor": TEXTO2, "axes.titlecolor": TEXTO,
        "axes.titlesize": 9.5, "axes.titleweight": "bold", "axes.titlelocation": "left",
        "xtick.color": TEXTO2, "ytick.color": TEXTO2, "legend.frameon": False,
        "figure.facecolor": "white", "savefig.facecolor": "white",
    })


def limpar(ax):
    ax.grid(axis="y", color=GRADE, lw=0.7, zorder=0)
    ax.set_axisbelow(True)
    for lado in ("top", "right"):
        ax.spines[lado].set_visible(False)
    ax.tick_params(length=0)


def ler(caminho, estat):
    linhas = list(csv.DictReader(open(caminho, encoding="utf-8")))
    dados = {}
    for r in linhas:
        q, forma = re.match(r"(Q\d+)([a-z])", r["forma"]).groups()
        execs = [float(r[k]) for k in r if k.startswith("exec_")]
        valor = statistics.mean(execs) if estat == "media" else statistics.median(execs)
        dados.setdefault(q, {})[forma] = {
            "valor": valor, "desvio": statistics.stdev(execs) if len(execs) > 1 else 0.0,
            "execs": execs, "descricao": r["descricao"], "linhas": int(r["linhas"]),
        }
    consultas = sorted(dados, key=lambda q: int(q[1:]))
    formas = sorted({f for q in dados for f in dados[q]})
    return dados, consultas, formas


def salvar(fig, saida, nome, formatos):
    for fmt in formatos:
        fig.savefig(os.path.join(saida, f"{nome}.{fmt}"), dpi=200, bbox_inches="tight")
    plt.close(fig)


def comparativo_geral(dados, qs, formas, cores, rotulo, saida, formatos):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(7.0, 5.6), sharex=True,
                                   gridspec_kw={"height_ratios": [1.15, 1], "hspace": 0.32})
    x = np.arange(len(qs))
    w = 0.8 / len(formas)
    for i, f in enumerate(formas):
        xs = x + (i - (len(formas) - 1) / 2) * w
        val = [dados[q][f]["valor"] if f in dados[q] else np.nan for q in qs]
        dp = [dados[q][f]["desvio"] if f in dados[q] else 0 for q in qs]
        raz = [dados[q][f]["valor"] / dados[q]["a"]["valor"] if f in dados[q] else np.nan for q in qs]
        ax1.bar(xs, val, w * 0.88, color=cores[i], label=f"forma ({f})", zorder=3)
        baixo = [min(e, 0.6 * v) if v == v else 0 for e, v in zip(dp, val)]
        ax1.errorbar(xs, val, yerr=[baixo, dp], fmt="none", ecolor="#3a3a3a", elinewidth=0.6,
                     capsize=1.6, zorder=4)
        ax2.bar(xs, raz, w * 0.88, color=cores[i], zorder=3)
        for xi, r in zip(xs, raz):
            if f != "a" and r == r and (r <= 0.5 or r >= 1.5):
                extra = 0.14 if (i == len(formas) - 1 and r < 0.5) else 0.03
                ax2.text(xi, r + extra, br(r, 2), ha="center", va="bottom", fontsize=6.6, color=TEXTO)
    ax1.set_yscale("log")
    ax1.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: br(v, 0)))
    ax1.set_ylabel(f"tempo {rotulo} (ms, escala log.)")
    ax1.set_title(f"Tempo {rotulo} de cada forma (barras de erro: desvio padrão)")
    ax1.legend(ncol=len(formas), loc="upper left", fontsize=8)
    ax2.axhline(1, color="#6b6b6b", lw=0.9, ls=(0, (4, 3)), zorder=2)
    ax2.set_ylim(0, max(2.05, np.nanmax([dados[q][f]["valor"] / dados[q]["a"]["valor"]
                                         for q in qs for f in dados[q]]) + 0.25))
    ax2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: br(v, 1)))
    ax2.set_ylabel("razão em relação à forma (a)")
    ax2.set_title("Tempo relativo à forma (a): abaixo da linha = mais rápida")
    ax2.set_xticks(x)
    ax2.set_xticklabels(qs)
    for ax in (ax1, ax2):
        limpar(ax)
    salvar(fig, saida, "comparativo_geral", formatos)


def painel(ax, q, dados, formas, cores, mostrar_y=True):
    fs = [f for f in formas if f in dados[q]]
    val = [dados[q][f]["valor"] for f in fs]
    dp = [dados[q][f]["desvio"] for f in fs]
    xs = np.arange(len(fs))
    ax.bar(xs, val, 0.62, color=[cores[formas.index(f)] for f in fs], zorder=3)
    ax.errorbar(xs, val, yerr=dp, fmt="none", ecolor="#3a3a3a", elinewidth=0.6, capsize=2, zorder=4)
    topo = max(v + d for v, d in zip(val, dp))
    for xi, f, v, d in zip(xs, fs, val, dp):
        txt = br(v, 0) if v >= 100 else br(v, 1)
        if f != "a":
            txt += f"\n{br(v / dados[q]['a']['valor'], 2)}x"
        ax.text(xi, v + d + topo * 0.03, txt, ha="center", va="bottom", fontsize=6.6, color=TEXTO,
                linespacing=1.1)
    ax.set_ylim(0, topo * 1.42)
    ax.set_xticks(xs)
    ax.set_xticklabels([f"({f})" for f in fs])
    ax.set_title(f"{q} · {CATEGORIA.get(int(q[1:]), '')}", fontsize=8.5)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: br(v, 0)))
    if not mostrar_y:
        ax.set_yticklabels([])
    limpar(ax)


def por_consulta(dados, qs, formas, cores, rotulo, saida, formatos):
    linhas = int(np.ceil(len(qs) / 5))
    fig, axs = plt.subplots(linhas, 5, figsize=(7.6, 2.4 * linhas))
    axs = np.atleast_1d(axs).ravel()
    for ax, q in zip(axs, qs):
        painel(ax, q, dados, formas, cores)
    for ax in axs[len(qs):]:
        ax.axis("off")
    fig.suptitle(f"Tempo {rotulo} (ms) por consulta; abaixo de cada valor, a razão em relação à forma (a)",
                 x=0.01, ha="left", fontsize=9.5, fontweight="bold", color=TEXTO)
    fig.tight_layout(rect=(0, 0, 1, 0.97), h_pad=1.6, w_pad=0.6)
    salvar(fig, saida, "por_consulta", formatos)


def cold_start(dados, qs, formas, cores, saida, formatos):
    fig, ax = plt.subplots(figsize=(7.0, 2.8))
    x = np.arange(len(qs))
    w = 0.8 / len(formas)
    todas = []
    for i, f in enumerate(formas):
        xs = x + (i - (len(formas) - 1) / 2) * w
        razoes = []
        for q in qs:
            if f in dados[q] and len(dados[q][f]["execs"]) > 1:
                e = dados[q][f]["execs"]
                razoes.append(e[0] / statistics.mean(e[1:]))
            else:
                razoes.append(np.nan)
        ax.bar(xs, razoes, w * 0.88, color=cores[i], label=f"forma ({f})", zorder=3)
        todas += [r for r in razoes if r == r]
        for xi, r in zip(xs, razoes):
            if r == r and r >= 1.5:
                ax.text(xi, r + 0.08, br(r, 1) + "x", ha="center", va="bottom", fontsize=6.6, color=TEXTO)
    ax.axhline(1, color="#6b6b6b", lw=0.9, ls=(0, (4, 3)), zorder=2)
    ax.set_xticks(x)
    ax.set_xticklabels(qs)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: br(v, 1)))
    ax.set_ylabel("1ª execução ÷ média das demais")
    ax.set_title("Efeito cold start: quanto a 1ª execução foi mais lenta que as seguintes")
    ax.set_ylim(0, np.nanmax(todas) * 1.18 if todas else 2)
    ax.legend(ncol=len(formas), loc="upper left", fontsize=8)
    limpar(ax)
    salvar(fig, saida, "cold_start", formatos)


def individuais(dados, qs, formas, cores, rotulo, saida, formatos):
    pasta = os.path.join(saida, "consultas")
    os.makedirs(pasta, exist_ok=True)
    for q in qs:
        fig, ax = plt.subplots(figsize=(5.6, 3.4))
        painel(ax, q, dados, formas, cores)
        fs = [f for f in formas if f in dados[q]]
        ax.set_xticklabels(["\n".join(textwrap.wrap(f"({f}) {dados[q][f]['descricao']}", 30)[:3])
                            for f in fs], fontsize=6.8)
        ax.set_ylabel(f"tempo {rotulo} (ms)")
        salvar(fig, pasta, q, formatos)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="tempos.csv")
    ap.add_argument("--saida", default="graficos")
    ap.add_argument("--paleta", default="ametista")
    ap.add_argument("--estatistica", choices=["media", "mediana"], default="media")
    ap.add_argument("--formatos", default="pdf,png")
    args = ap.parse_args()

    cores = PALETAS.get(args.paleta) or [c.strip() for c in args.paleta.split(",")]
    formatos = [f.strip() for f in args.formatos.split(",") if f.strip()]
    rotulo = "médio" if args.estatistica == "media" else "mediano"
    os.makedirs(args.saida, exist_ok=True)
    estilo()

    dados, qs, formas = ler(args.csv, args.estatistica)
    if len(cores) < len(formas):
        raise SystemExit(f"A paleta precisa de {len(formas)} cores.")
    comparativo_geral(dados, qs, formas, cores, rotulo, args.saida, formatos)
    por_consulta(dados, qs, formas, cores, rotulo, args.saida, formatos)
    cold_start(dados, qs, formas, cores, args.saida, formatos)
    individuais(dados, qs, formas, cores, rotulo, args.saida, formatos)
    print(f"Graficos salvos em ./{args.saida}/ (comparativo_geral, por_consulta, cold_start, consultas/Q1..Q{len(qs)})")


if __name__ == "__main__":
    main()
