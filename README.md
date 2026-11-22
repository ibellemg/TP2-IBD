# TP2 – Grupo 5 – Gestão de médicos e plantões (versão MySQL)

Tudo aqui segue o diagrama ER entregue (`ER_TP2_GRUPO_5.pdf`): 6 entidades (Profissional, Plantão, Unidade, Atendimento, Paciente, Remédio), 6 relacionamentos e os atributos multivalorados `especialidades` e `contatos`.

## Conteúdo do pacote

| Arquivo | Para que serve |
|---|---|
| `01_esquema.sql` | Cria o banco `tp2_plantoes` e as 10 tabelas, com PK, FK (com ON DELETE/UPDATE), UNIQUE, NOT NULL e CHECK |
| `gerar_dados.py` | Gera os CSVs com 1 milhão de atendimentos (só usa Python 3) |
| `02_carregar_dados.sql` | Carrega os CSVs no MySQL (`LOAD DATA`) e confere os volumes |
| `04_gatilhos.sql` | Gatilhos com as regras de negócio que o ER não expressa, mais exemplos para demonstrar |
| `preparar_banco.sh` | **Linux:** gera os dados, cria o banco, carrega tudo e cria os gatilhos com um comando |
| `03_consultas.sql` | As 10 consultas, cada uma em 3 formas |
| `medir_tempos.py` | Roda cada forma 5 vezes e calcula as estatísticas (veja abaixo) |

## Passo a passo no Linux (Ubuntu)

1. **Instalar** (uma vez): `sudo apt install mysql-server python3-venv` e `sudo snap install mysql-workbench-community`. Defina a senha do root com `sudo mysql` e depois:
   `ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'sua_senha';`
2. **Preparar o banco:** `bash preparar_banco.sh`. Ele **gera os dados de novo** (apaga a pasta `dados` antiga), recria o banco do zero, carrega os CSVs e cria os gatilhos. No fim, mostra quantas linhas entraram em cada tabela.
3. **Ver e rodar as consultas:** no Workbench, abra o `03_consultas.sql` (limite de linhas em *Don't Limit* se for medir à mão).
4. **Medir os tempos:**
   ```bash
   python3 -m venv venv && source venv/bin/activate
   pip install mysql-connector-python
   python3 medir_tempos.py
   ```
5. **Esquema relacional para o relatório:** no Workbench, use *Database → Reverse Engineer* no banco `tp2_plantoes`.

No Windows, rode no Workbench, nesta ordem: `01_esquema.sql`, `02_carregar_dados.sql` (seguindo as instruções no topo) e `04_gatilhos.sql`.

## Restrições de integridade

| Tipo | Onde |
|---|---|
| PRIMARY KEY | todas as tabelas; chaves compostas nos M:N e nos multivalorados |
| FOREIGN KEY | os 6 relacionamentos e os 2 multivalorados, com `ON DELETE`/`ON UPDATE`: CASCADE nos multivalorados e nas tabelas dos M:N quando o "dono" é apagado; RESTRICT onde apagar quebraria o histórico (não se apaga um profissional que já atendeu) |
| NOT NULL | atributos obrigatórios e participação total (FKs de `plantao` e `atendimento`) |
| UNIQUE | `cpf` (profissional e paciente), nome da unidade, (nome, fabricante) do remédio, (unidade, data, turno) do plantão |
| CHECK | valores válidos de cargo, turno, função, tipo de unidade, tipo de atendimento e tarja; CPF com 11 dígitos; carga horária entre 12 e 60 h; duração de 6 h (manhã/tarde) ou 12 h (noite) |
| Gatilhos (`04_gatilhos.sql`) | **R1:** quem realiza o atendimento está escalado no plantão. **R2:** o atendimento cai no horário do plantão. **R3:** só médicos prescrevem. **R4:** não se pode remover o último profissional de um plantão (participação total de Plantão em *Escalado em*) |

O final do `04_gatilhos.sql` tem um exemplo de comando que cada regra recusa, para mostrar no vídeo.

A única parte da regra R4 que fica de fora: impedir que um plantão seja **criado** sem ninguém escalado. Isso exigiria verificar a regra no fim de uma transação, e o MySQL não oferece esse tipo de verificação.

## Consultas e formas comparadas

| Consulta | Categoria | Relacionamentos do ER | Forma a | Forma b | Forma c |
|---|---|---|---|---|---|
| Q1 | seleção/projeção | Profissional | sem índice | índice (cargo, carga_horaria) | índice de cobertura |
| Q2 | seleção/projeção | Plantão | BETWEEN sem índice | BETWEEN com índice | YEAR()/MONTH() com índice |
| Q3 | junção de 2 | *Ocorre em* | JOIN | junção no WHERE, FROM invertido | subconsultas IN e escalar |
| Q4 | junção de 2 | *Prescreve* | JOIN | STRAIGHT_JOIN | tabela derivada filtrada |
| Q5 | junção de 2 | *Recebe* | JOIN | índice (tipo, diagnostico) | STRAIGHT_JOIN começando por paciente |
| Q6 | junção de 5 | *Recebe*, *Realiza*, *Ocorre durante*, *Ocorre em* | JOINs | subconsultas escalares | índice (tipo, diagnostico) |
| Q7 | junção de 3 | *Recebe*, *Realiza*, {especialidades} | JOIN + DISTINCT | EXISTS | IN |
| Q8 | junção de 4 | *Escalado em* (funcao), *Ocorre em* | JOINs | índice (turno, data) | STRAIGHT_JOIN unidade→plantão→escala→profissional |
| Q9 | agregação | *Ocorre durante*, *Ocorre em* | JOIN + GROUP BY | agrega em tabela derivada | subconsulta correlacionada por unidade |
| Q10 | agregação | *Prescreve* | JOIN | subconsulta IN | índice (tipo) |

As três formas de cada consulta retornam exatamente o mesmo resultado. O `medir_tempos.py` confere isso a cada execução, comparando o conteúdo das linhas e não só a quantidade.

## Estatísticas da medição

O `medir_tempos.py` gera três arquivos:
- **`tempos.csv`**: os 5 tempos de cada forma e as estatísticas;
- **`tempos.md`**: uma tabela pronta para o relatório;
- **`explain.txt`**: o plano de execução de cada forma.

| Estatística | Para que serve no relatório |
|---|---|
| média | o valor que o enunciado pede |
| mediana | menos sensível a uma execução fora da curva |
| desvio padrão, mínimo e máximo | mostram a variação entre as 5 execuções |
| coeficiente de variação (CV = desvio/média) | variação relativa; acima de ~20%, a medida está instável |
| tempo da 1ª execução | mostra o efeito "cold start" citado no enunciado |
| razão em relação à forma "a" | 0,25x = 4 vezes mais rápida; 2,0x = 2 vezes mais lenta |

Opção `--aquecimento N`: roda N execuções extras antes de medir e as descarta. O padrão é 0, para seguir o enunciado.

## Dados gerados

| Tabela | Linhas |
|---|---|
| unidade | 40 (hospitais, UPAs, policlínicas e maternidades) |
| profissional | 10.000 |
| profissional_especialidade | ~8.500 |
| plantao | ~83.000 (por unidade, dia e turno, 2024–2025; policlínicas sem plantão noturno) |
| escalado_em | ~250.000 |
| paciente | 200.000 |
| paciente_contato | ~310.000 |
| remedio | ~150 |
| atendimento | 1.000.000 |
| prescricao | ~1.100.000 |

Regras de realismo respeitadas pelo gerador:
- os turnos têm horário real: manhã 7h–13h, tarde 13h–19h e noite 19h–7h do dia seguinte;
- cada profissional trabalha numa unidade e em no máximo um turno por dia;
- todo plantão tem um médico coordenador;
- os atendimentos são feitos por médicos (85%) ou enfermeiros (15%) escalados no plantão;
- só médicos prescrevem;
- pediatras atendem crianças, e os demais atendem principalmente adultos;
- o perfil muda com o tipo de unidade: UPA com mais emergências, policlínica com mais consultas, maternidade com mais procedimentos;
- os CPFs são válidos e únicos.

Todas essas regras foram conferidas nos dados gerados, e nenhuma linha as viola. A semente é fixa, então rodar o gerador de novo produz exatamente os mesmos dados.

## Mudanças em relação à versão da colega (PostgreSQL)

1. Chaves estrangeiras declaradas com `FOREIGN KEY ... REFERENCES` no fim de cada tabela (o MySQL ignora o `REFERENCES` escrito na linha da coluna).
2. `data_hora` passou de `TIMESTAMP` para `DATETIME`.
3. Carga com `LOAD DATA LOCAL INFILE` no lugar do `\copy`.
4. Q5 virou Atendimento × Paciente; Q7 passou a usar `DISTINCT p.id_paciente, ...`; Q8 passou a usar *Escalado em*.
5. Restrições CHECK, ações de ON DELETE/UPDATE e gatilhos acrescentados.
6. Três formas em todas as consultas.

**Dica para o relatório:** no MySQL, só inverter a ordem das tabelas no FROM normalmente não muda o tempo, porque o otimizador reordena as junções sozinho. É por isso que Q4, Q5 e Q8 usam `STRAIGHT_JOIN`. Se a Q3a e a Q3b derem tempos iguais, esse resultado também vale e merece comentário.
