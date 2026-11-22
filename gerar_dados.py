"""
TP2 - Introducao a Banco de Dados - Grupo 5 - Gestao de medicos e plantoes
Gerador de dados sinteticos coerentes para o banco tp2_plantoes.

Uso:
    python gerar_dados.py              -> gera os CSVs na pasta ./dados
    python gerar_dados.py --escala 0.1 -> versao reduzida (10%), para testes

Nao precisa instalar nada: usa so a biblioteca padrao do Python 3.

Regras de coerencia garantidas (as mesmas que os gatilhos verificam):
  - um plantao por unidade, dia e turno; policlinicas nao tem plantao noturno;
  - Manha 07h-13h e Tarde 13h-19h (6 h); Noite 19h-07h do dia seguinte (12 h);
  - todo plantao tem um medico coordenador;
  - cada profissional trabalha em uma unidade e em no maximo um turno por dia;
  - o atendimento e feito por um medico ou enfermeiro escalado no plantao e
    cai dentro do horario do plantao;
  - so medicos prescrevem; um remedio aparece no maximo uma vez por atendimento;
  - pediatras atendem criancas; os demais atendem principalmente adultos;
  - o perfil de atendimento muda com o tipo de unidade (UPA: mais emergencias,
    policlinica: mais consultas, maternidade: mais procedimentos);
  - CPFs validos (com digitos verificadores) e unicos.
"""
import argparse
import csv
import datetime as dt
import os
import random

# ---------------------------------------------------------------------
# Parametros (volume padrao: ~1 milhao de atendimentos)
# ---------------------------------------------------------------------
N_UNIDADES = 40
N_PROFISSIONAIS = 10_000
N_PACIENTES = 200_000
N_ATENDIMENTOS = 1_000_000
DATA_INICIO = dt.date(2024, 1, 1)
DATA_FIM = dt.date(2025, 12, 31)
SEMENTE = 2026

PRIMEIROS = ["Ana", "Bruno", "Carla", "Diego", "Eduarda", "Felipe", "Gabriela", "Henrique",
             "Isabela", "Joao", "Julia", "Lucas", "Mariana", "Marcos", "Natalia", "Otavio",
             "Paula", "Pedro", "Rafaela", "Rodrigo", "Sofia", "Thiago", "Vanessa", "Vitor",
             "Amanda", "Caio", "Beatriz", "Daniel", "Elisa", "Fabio", "Helena", "Igor",
             "Larissa", "Leonardo", "Livia", "Matheus", "Nicole", "Renato", "Sara", "Tiago",
             "Antonio", "Camila", "Gustavo", "Laura", "Marcelo", "Patricia", "Ricardo", "Teresa",
             "Alice", "Bernardo", "Cecilia", "Davi", "Fernanda", "Guilherme", "Heloisa", "Joana"]
SOBRENOMES = ["Silva", "Souza", "Oliveira", "Santos", "Lima", "Pereira", "Costa", "Ferreira",
              "Rodrigues", "Almeida", "Carvalho", "Gomes", "Martins", "Araujo", "Ribeiro", "Barbosa",
              "Rocha", "Dias", "Mendes", "Moreira", "Cardoso", "Teixeira", "Nunes", "Freitas",
              "Campos", "Vieira", "Castro", "Pinto", "Moura", "Correia", "Fonseca", "Ramos",
              "Machado", "Lopes", "Batista", "Monteiro", "Andrade", "Faria", "Duarte", "Reis"]

TIPOS_UNIDADE = [("Hospital", 0.40), ("UPA", 0.30), ("Policlinica", 0.20), ("Maternidade", 0.10)]
REGIOES = ["Norte", "Sul", "Leste", "Oeste", "Centro", "Barreiro", "Pampulha", "Venda Nova",
           "Nordeste", "Noroeste"]

CARGOS = [("Medico", 0.45), ("Enfermeiro", 0.25), ("Tecnico de Enfermagem", 0.22),
          ("Fisioterapeuta", 0.08)]
CARGAS = [20, 24, 30, 36, 40, 44]
ESPECIALIDADES = {
    "Medico": ["Clinica Geral", "Cardiologia", "Pediatria", "Ortopedia", "Neurologia",
               "Ginecologia", "Dermatologia", "Pneumologia", "Endocrinologia", "Psiquiatria",
               "Cirurgia Geral", "Medicina Intensiva", "Infectologia", "Geriatria"],
    "Enfermeiro": ["Enfermagem em UTI", "Enfermagem Obstetrica", "Enfermagem Pediatrica"],
    "Tecnico de Enfermagem": [],
    "Fisioterapeuta": ["Fisioterapia Respiratoria", "Fisioterapia Motora"],
}

TURNOS = [("Manha", 6, 7), ("Tarde", 6, 13), ("Noite", 12, 19)]  # nome, duracao (h), hora de inicio
PESO_TURNO = {"Manha": 1.0, "Tarde": 1.0, "Noite": 0.7}

# pesos de (Consulta, Emergencia, Retorno, Procedimento) por tipo de unidade
TIPOS_ATEND = ["Consulta", "Emergencia", "Retorno", "Procedimento"]
PERFIL_UNIDADE = {"Hospital": [30, 30, 20, 20], "UPA": [20, 60, 10, 10],
                  "Policlinica": [60, 5, 30, 5], "Maternidade": [30, 20, 15, 35]}
DIAGNOSTICOS = ["Gripe", "Hipertensao", "Diabetes", "Fratura", "Asma", "Pneumonia", "Dermatite",
                "Gastroenterite", "Infeccao urinaria", "Lombalgia", "Enxaqueca", "Ansiedade",
                "Depressao", "Covid-19", "Dengue", "Sinusite", "Otite", "Conjuntivite",
                "Entorse", "Arritmia", "Insuficiencia cardiaca", "Bronquite", "Anemia",
                "Hipotireoidismo", "Insonia"]

# principio ativo, tarja
PRINCIPIOS = [("Clonazepam", "Preta"), ("Diazepam", "Preta"), ("Alprazolam", "Preta"),
              ("Zolpidem", "Preta"), ("Morfina", "Preta"), ("Midazolam", "Preta"),
              ("Amoxicilina", "Vermelha"), ("Azitromicina", "Vermelha"), ("Cefalexina", "Vermelha"),
              ("Ciprofloxacino", "Vermelha"), ("Losartana", "Vermelha"), ("Enalapril", "Vermelha"),
              ("Metformina", "Vermelha"), ("Sinvastatina", "Vermelha"), ("Omeprazol", "Vermelha"),
              ("Prednisona", "Vermelha"), ("Fluoxetina", "Vermelha"), ("Sertralina", "Vermelha"),
              ("Levotiroxina", "Vermelha"), ("Salbutamol", "Vermelha"), ("Insulina NPH", "Vermelha"),
              ("Tramadol", "Vermelha"), ("Furosemida", "Vermelha"), ("Varfarina", "Vermelha"),
              ("Dipirona", "Sem tarja"), ("Paracetamol", "Sem tarja"), ("Ibuprofeno", "Sem tarja"),
              ("Loratadina", "Sem tarja"), ("Sulfato ferroso", "Sem tarja"),
              ("Soro de reidratacao oral", "Sem tarja")]
FABRICANTES = ["EMS", "Medley", "Eurofarma", "Ache", "Sanofi", "Roche", "Pfizer", "Novartis",
               "Cristalia", "Germed", "Neo Quimica", "Libbs"]
CONCENTRACOES = ["5 mg", "10 mg", "20 mg", "50 mg", "250 mg", "500 mg", "1 g"]
DOSES = ["1 comprimido", "2 comprimidos", "5 mg", "10 mg", "250 mg", "500 mg", "1 g", "10 gotas",
         "20 gotas", "1 ampola"]
FREQUENCIAS = ["4/4h", "6/6h", "8/8h", "12/12h", "1x ao dia", "se necessario"]


def cpf_valido(rng, usados):
    while True:
        base = [rng.randint(0, 9) for _ in range(9)]
        if len(set(base)) == 1:
            continue
        for peso_ini in (10, 11):
            soma = sum(d * p for d, p in zip(base, range(peso_ini, 1, -1)))
            dv = (soma * 10) % 11
            base.append(0 if dv == 10 else dv)
        cpf = "".join(map(str, base))
        if cpf not in usados:
            usados.add(cpf)
            return cpf


def nome_pessoa(rng):
    return f"{rng.choice(PRIMEIROS)} {rng.choice(SOBRENOMES)} {rng.choice(SOBRENOMES)}"


def escolher(rng, pares):
    return rng.choices([p[0] for p in pares], weights=[p[1] for p in pares])[0]


def escritor(pasta, nome, cabecalho):
    f = open(os.path.join(pasta, nome + ".csv"), "w", newline="", encoding="utf-8")
    w = csv.writer(f, lineterminator="\n")
    w.writerow(cabecalho)
    return f, w


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--escala", type=float, default=1.0, help="fator de volume (padrao 1.0)")
    ap.add_argument("--saida", default="dados", help="pasta de saida (padrao ./dados)")
    args = ap.parse_args()

    n_prof = max(200, int(N_PROFISSIONAIS * args.escala))
    n_pac = max(500, int(N_PACIENTES * args.escala))
    n_atend = max(1000, int(N_ATENDIMENTOS * args.escala))
    rng = random.Random(SEMENTE)
    os.makedirs(args.saida, exist_ok=True)
    cpfs = set()

    # --- Unidades -----------------------------------------------------
    f, w = escritor(args.saida, "unidade", ["id_unidade", "nome", "tipo"])
    unidades = []
    for i in range(1, N_UNIDADES + 1):
        tipo = escolher(rng, TIPOS_UNIDADE)
        nome = f"{tipo} {REGIOES[(i - 1) % len(REGIOES)]} {(i - 1) // len(REGIOES) + 1:02d}"
        peso = rng.lognormvariate(0, 0.45)  # algumas unidades bem mais movimentadas
        unidades.append((i, tipo, peso))
        w.writerow([i, nome, tipo])
    f.close()

    # --- Profissionais (cada um lotado em uma unidade) ----------------
    f, w = escritor(args.saida, "profissional", ["id_prof", "cpf", "nome", "cargo", "carga_horaria"])
    fe, we = escritor(args.saida, "profissional_especialidade", ["id_prof", "especialidade"])
    cargo_de = {}
    lotados = {u[0]: {"Medico": [], "Enfermeiro": [], "outros": []} for u in unidades}
    pediatras = set()
    for p in range(1, n_prof + 1):
        cargo = escolher(rng, CARGOS)
        cargo_de[p] = cargo
        w.writerow([p, cpf_valido(rng, cpfs), nome_pessoa(rng), cargo, rng.choice(CARGAS)])
        u = rng.randint(1, N_UNIDADES)
        lotados[u][cargo if cargo in ("Medico", "Enfermeiro") else "outros"].append(p)
        opcoes = ESPECIALIDADES[cargo]
        if opcoes:
            if cargo == "Medico":
                k = rng.choices([1, 2, 3], weights=[60, 30, 10])[0]
            else:
                k = rng.choices([0, 1], weights=[50, 50])[0]
            for esp in rng.sample(opcoes, k):
                we.writerow([p, esp])
                if esp == "Pediatria":
                    pediatras.add(p)
    f.close(); fe.close()
    # garante gente suficiente em cada unidade para os 3 turnos do dia
    minimo = {"Medico": 6, "Enfermeiro": 3, "outros": 3}
    conds = {"Medico": lambda c: c == "Medico", "Enfermeiro": lambda c: c == "Enfermeiro",
             "outros": lambda c: c not in ("Medico", "Enfermeiro")}
    for u in lotados:
        for grupo, cond in conds.items():
            while len(lotados[u][grupo]) < minimo[grupo]:
                lotados[u][grupo].append(rng.choice(
                    [p for p, c in cargo_de.items() if cond(c) and p not in lotados[u][grupo]]))

    # --- Plantoes e escala -------------------------------------------
    f, w = escritor(args.saida, "plantao", ["id_plantao", "data", "duracao_h", "turno", "id_unidade"])
    fe, we = escritor(args.saida, "escalado_em", ["id_prof", "id_plantao", "funcao"])
    plantoes = []  # (id, inicio, duracao, tipo_unidade, medicos, enfermeiros)
    pesos_plantao = []
    pid = 0
    dia = DATA_INICIO
    while dia <= DATA_FIM:
        for (u, tipo_u, peso_u) in unidades:
            turnos = [t for t in TURNOS if not (tipo_u == "Policlinica" and t[0] == "Noite")]
            # cada profissional trabalha em no maximo um turno por dia
            qtd_med = [rng.randint(1, 2) for _ in turnos]
            qtd_out = [rng.randint(0, 1) for _ in turnos]
            meds_dia = rng.sample(lotados[u]["Medico"], sum(qtd_med))
            enfs_dia = rng.sample(lotados[u]["Enfermeiro"], len(turnos))
            outs_dia = rng.sample(lotados[u]["outros"], sum(qtd_out))
            for k, (turno, dur, h_ini) in enumerate(turnos):
                pid += 1
                w.writerow([pid, dia.isoformat(), dur, turno, u])
                meds = [meds_dia.pop() for _ in range(qtd_med[k])]
                enfs = [enfs_dia.pop()]
                outs = [outs_dia.pop() for _ in range(qtd_out[k])]
                we.writerow([meds[0], pid, "Coordenador"])
                for m in meds[1:]:
                    we.writerow([m, pid, "Plantonista"])
                for o in enfs + outs:
                    we.writerow([o, pid, "Assistencia"])
                inicio = dt.datetime(dia.year, dia.month, dia.day, h_ini)
                plantoes.append((pid, inicio, dur, tipo_u, meds, enfs))
                pesos_plantao.append(peso_u * PESO_TURNO[turno])
        dia += dt.timedelta(days=1)
    f.close(); fe.close()

    # --- Pacientes e contatos ----------------------------------------
    f, w = escritor(args.saida, "paciente", ["id_paciente", "cpf", "nome", "data_nasc"])
    fc, wc = escritor(args.saida, "paciente_contato", ["id_paciente", "contato"])
    criancas, adultos = [], []
    for i in range(1, n_pac + 1):
        nasc = dt.date(1930, 1, 1) + dt.timedelta(days=rng.randint(0, 34_000))
        nome = nome_pessoa(rng)
        w.writerow([i, cpf_valido(rng, cpfs), nome, nasc.isoformat()])
        if nasc >= dt.date(2011, 1, 1):
            criancas.append(i)
        elif nasc < dt.date(2008, 1, 1):
            adultos.append(i)
        contatos = set()
        for _ in range(rng.choices([1, 2, 3], weights=[55, 35, 10])[0]):
            if rng.random() < 0.75:
                contatos.add(f"(31) 9{rng.randint(1000, 9999)}-{rng.randint(1000, 9999)}")
            else:
                pri, sob = nome.split()[0].lower(), nome.split()[1].lower()
                contatos.add(f"{pri}.{sob}{rng.randint(1, 999)}@email.com")
        for c in contatos:
            wc.writerow([i, c])
    f.close(); fc.close()

    # --- Remedios ------------------------------------------------------
    f, w = escritor(args.saida, "remedio", ["id_remedio", "nome", "fabricante", "principio_ativo", "tarja"])
    remedios = []
    rid = 0
    for princ, tarja in PRINCIPIOS:
        for fab in rng.sample(FABRICANTES, rng.randint(3, 7)):
            rid += 1
            w.writerow([rid, f"{princ} {rng.choice(CONCENTRACOES)}", fab, princ, tarja])
            remedios.append(rid)
    f.close()

    # --- Atendimentos e prescricoes ----------------------------------
    f, w = escritor(args.saida, "atendimento",
                    ["id_atend", "data_hora", "tipo", "diagnostico", "id_prof", "id_paciente", "id_plantao"])
    fp, wp = escritor(args.saida, "prescricao", ["id_atend", "id_remedio", "dose", "frequencia"])
    escolhidos = rng.choices(range(len(plantoes)), weights=pesos_plantao, k=n_atend)
    escolhidos.sort()  # atendimentos em ordem cronologica
    n_presc = 0
    for aid, idx in enumerate(escolhidos, start=1):
        pid, inicio, dur, tipo_u, meds, enfs = plantoes[idx]
        prof = rng.choice(meds) if rng.random() < 0.85 else rng.choice(enfs)
        hora = inicio + dt.timedelta(minutes=rng.randint(0, dur * 60 - 1))
        if prof in pediatras:
            paciente = rng.choice(criancas)
        elif rng.random() < 0.9:
            paciente = rng.choice(adultos)
        else:
            paciente = rng.randint(1, n_pac)
        w.writerow([aid, hora.strftime("%Y-%m-%d %H:%M:%S"),
                    rng.choices(TIPOS_ATEND, weights=PERFIL_UNIDADE[tipo_u])[0], rng.choice(DIAGNOSTICOS),
                    prof, paciente, pid])
        if cargo_de[prof] == "Medico":
            k = rng.choices([0, 1, 2, 3], weights=[25, 35, 25, 15])[0]
            for rem in rng.sample(remedios, k):
                wp.writerow([aid, rem, rng.choice(DOSES), rng.choice(FREQUENCIAS)])
                n_presc += 1
    f.close(); fp.close()

    print(f"Pronto! CSVs em ./{args.saida}")
    print(f"  unidades={N_UNIDADES} profissionais={n_prof} plantoes={len(plantoes)} "
          f"pacientes={n_pac} remedios={len(remedios)} atendimentos={n_atend} prescricoes={n_presc}")


if __name__ == "__main__":
    main()
