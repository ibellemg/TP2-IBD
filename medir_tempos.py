"""
TP2 - Grupo 5 - Mede o tempo de todas as formas das consultas.

Le o arquivo 03_consultas.sql (marcadores "-- @@"), executa cada forma
N vezes (padrao 5, como pede o enunciado) e salva:
  - tempos.csv    : os tempos de cada execucao e as estatisticas
  - tempos.md     : tabela pronta para colar no relatorio
  - explain.txt   : o plano de execucao (EXPLAIN) de cada forma

Estatisticas por forma: media, mediana, desvio padrao, minimo, maximo,
coeficiente de variacao (desvio/media), tempo da 1a execucao (efeito
"cold start") e razao em relacao a forma "a" da mesma consulta.
Tambem confere se todas as formas de uma consulta devolvem exatamente o
mesmo resultado (mesmo numero de linhas e mesmo conteudo).

Instalacao (uma vez):  pip install mysql-connector-python
Uso:                   python3 medir_tempos.py
Opcoes:                --repeticoes 5  --aquecimento 0  --usuario root  --host localhost
A senha e pedida no terminal.
"""
import argparse
import csv
import getpass
import hashlib
import re
import statistics
import time

import mysql.connector


def ler_blocos(caminho):
    """Lista de blocos (tipo, id, descricao, sql) na ordem do arquivo."""
    blocos, atual = [], None
    for linha in open(caminho, encoding="utf-8"):
        s = linha.strip()
        if s.startswith("-- @@"):
            if atual:
                blocos.append(atual)
            cab = s[5:].strip()
            if cab.startswith("SETUP") or cab.startswith("TEARDOWN"):
                tipo, ident = cab.split(None, 1)
                atual = [tipo, ident.strip(), "", []]
            else:
                partes = [p.strip() for p in cab.split("|")]
                atual = ["CONSULTA", partes[0], partes[-1], []]
        elif atual is not None:
            if s.startswith("-- ====") or (s.startswith("-- Q") and ":" in s):
                blocos.append(atual)
                atual = None
            elif s and not s.startswith("--"):
                atual[3].append(linha.rstrip())
    if atual:
        blocos.append(atual)
    return [(t, i, d, " ".join(sql).strip().rstrip(";")) for t, i, d, sql in blocos]


def assinatura(linhas, ordenado):
    """Resumo do conteudo do resultado, para comparar as formas entre si."""
    textos = [repr(l) for l in linhas]
    if not ordenado:
        textos.sort()
    return hashlib.md5("\n".join(textos).encode()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--porta", type=int, default=3306)
    ap.add_argument("--usuario", default="root")
    ap.add_argument("--banco", default="tp2_plantoes")
    ap.add_argument("--arquivo", default="03_consultas.sql")
    ap.add_argument("--repeticoes", type=int, default=5)
    ap.add_argument("--aquecimento", type=int, default=0,
                    help="execucoes extras antes das medidas, descartadas (padrao 0)")
    args = ap.parse_args()

    senha = getpass.getpass(f"Senha do MySQL para {args.usuario}: ")
    con = mysql.connector.connect(host=args.host, port=args.porta, user=args.usuario,
                                  password=senha, database=args.banco)
    cur = con.cursor()

    resultados, media_a, assinaturas = [], {}, {}
    with open("explain.txt", "w", encoding="utf-8") as fexp:
        for tipo, ident, desc, sql in ler_blocos(args.arquivo):
            if tipo in ("SETUP", "TEARDOWN"):
                for comando in [c.strip() for c in sql.split(";") if c.strip()]:
                    try:
                        cur.execute(comando)
                        print(f"   [{tipo} {ident}] {comando}")
                    except mysql.connector.Error as e:
                        if e.errno not in (1061, 1091):  # indice ja existe / nao existe
                            raise
                continue

            consulta = re.match(r"Q\d+", ident).group()

            cur.execute("EXPLAIN " + sql)
            plano = cur.fetchall()
            colunas = [c[0] for c in cur.description]
            fexp.write(f"===== {ident} - {desc}\n{sql}\n\n" + " | ".join(colunas) + "\n")
            for linha in plano:
                fexp.write(" | ".join("" if v is None else str(v) for v in linha) + "\n")
            fexp.write("\n")

            for _ in range(args.aquecimento):
                cur.execute(sql)
                cur.fetchall()

            tempos, linhas = [], []
            for _ in range(args.repeticoes):
                t0 = time.perf_counter()
                cur.execute(sql)
                linhas = cur.fetchall()
                tempos.append((time.perf_counter() - t0) * 1000)

            assinaturas.setdefault(consulta, []).append(
                (ident, len(linhas), assinatura(linhas, "ORDER BY" in sql.upper())))
            media = statistics.mean(tempos)
            desvio = statistics.stdev(tempos) if len(tempos) > 1 else 0.0
            media_a.setdefault(consulta, media)
            r = {
                "forma": ident, "descricao": desc, "linhas": len(linhas),
                "media_ms": media, "mediana_ms": statistics.median(tempos), "desvio_ms": desvio,
                "min_ms": min(tempos), "max_ms": max(tempos),
                "cv_pct": 100 * desvio / media if media else 0.0,
                "primeira_ms": tempos[0],
                "razao_vs_a": media / media_a[consulta],
                "execucoes": tempos,
            }
            resultados.append(r)
            print(f"{ident:5s} media {media:9.1f} ms | mediana {r['mediana_ms']:9.1f} | desvio {desvio:7.1f} "
                  f"| CV {r['cv_pct']:5.1f}% | x{r['razao_vs_a']:.2f} vs a | {len(linhas):7d} linhas")

    cur.close()
    con.close()

    print()
    for consulta, formas in assinaturas.items():
        if len({(n, h) for _, n, h in formas}) == 1:
            print(f"{consulta}: todas as formas devolveram o mesmo resultado ({formas[0][1]} linhas)")
        else:
            print(f"ATENCAO {consulta}: as formas devolveram resultados diferentes: "
                  + ", ".join(f"{i}={n} linhas" for i, n, _ in formas))

    n = args.repeticoes
    with open("tempos.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["forma", "descricao", "linhas"] + [f"exec_{i + 1}_ms" for i in range(n)]
                   + ["media_ms", "mediana_ms", "desvio_ms", "min_ms", "max_ms", "cv_pct",
                      "primeira_ms", "razao_vs_a"])
        for r in resultados:
            w.writerow([r["forma"], r["descricao"], r["linhas"]]
                       + [f"{t:.2f}" for t in r["execucoes"]]
                       + [f"{r[k]:.2f}" for k in ("media_ms", "mediana_ms", "desvio_ms", "min_ms",
                                                   "max_ms", "cv_pct", "primeira_ms", "razao_vs_a")])

    with open("tempos.md", "w", encoding="utf-8") as f:
        f.write(f"| Forma | Descricao | Linhas | Media ({n} exec.) | Desvio | Min | Max | CV | vs. forma a |\n")
        f.write("|---|---|---:|---:|---:|---:|---:|---:|---:|\n")
        for r in resultados:
            f.write(f"| {r['forma']} | {r['descricao']} | {r['linhas']} | {r['media_ms']:.1f} ms "
                    f"| {r['desvio_ms']:.1f} ms | {r['min_ms']:.1f} ms | {r['max_ms']:.1f} ms "
                    f"| {r['cv_pct']:.1f}% | {r['razao_vs_a']:.2f}x |\n")
    print("\nResultados salvos em tempos.csv, tempos.md e explain.txt")


if __name__ == "__main__":
    main()
