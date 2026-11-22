-- =====================================================================
-- TP2 - Grupo 5 - Gestao de medicos e plantoes
-- 10 consultas, cada uma em tres formas (MySQL 8.x)
-- =====================================================================
-- Como usar no Workbench: selecione um bloco e execute (Ctrl+Shift+Enter
-- executa so o comando onde esta o cursor). O tempo aparece na coluna
-- "Duration" do painel Output.
--
-- Blocos "SETUP" criam um indice antes de uma forma e blocos "TEARDOWN"
-- removem esse indice logo depois, para que ele nao interfira nas outras
-- medicoes. Rode-os na ordem em que aparecem.
--
-- As linhas que comecam com "-- @@" sao marcadores lidos pelo script
-- medir_tempos.py. Nao apague esses marcadores.
--
-- Observacao sobre indices: o MySQL ja cria indices para as chaves
-- primarias e estrangeiras. Por isso as formas "com indice" usam colunas
-- que nao sao chave (cargo, turno, tipo, data_hora...).
-- =====================================================================

USE tp2_plantoes;

-- =====================================================================
-- CONSULTAS COM SELECAO E PROJECAO
-- =====================================================================

-- Q1: Nome e CPF dos medicos com carga horaria de pelo menos 36 horas.

-- @@ Q1a | Q1 | Sem indice (varredura da tabela)
SELECT nome, cpf
FROM profissional
WHERE cargo = 'Medico'
  AND carga_horaria >= 36;

-- @@SETUP Q1b
CREATE INDEX idx_prof_cargo_carga ON profissional (cargo, carga_horaria);
-- @@ Q1b | Q1 | Com indice composto em (cargo, carga_horaria)
SELECT nome, cpf
FROM profissional
WHERE cargo = 'Medico'
  AND carga_horaria >= 36;
-- @@TEARDOWN Q1b
DROP INDEX idx_prof_cargo_carga ON profissional;

-- @@SETUP Q1c
CREATE INDEX idx_prof_cobertura ON profissional (cargo, carga_horaria, nome, cpf);
-- @@ Q1c | Q1 | Com indice de cobertura em (cargo, carga_horaria, nome, cpf): nao precisa ler a tabela
SELECT nome, cpf
FROM profissional
WHERE cargo = 'Medico'
  AND carga_horaria >= 36;
-- @@TEARDOWN Q1c
DROP INDEX idx_prof_cobertura ON profissional;


-- Q2: Codigo, data, duracao e unidade dos plantoes noturnos de marco/2025.

-- @@ Q2a | Q2 | BETWEEN sem indice
SELECT id_plantao, data, duracao_h, id_unidade
FROM plantao
WHERE turno = 'Noite'
  AND data BETWEEN DATE '2025-03-01' AND DATE '2025-03-31';

-- @@SETUP Q2b
CREATE INDEX idx_plantao_turno_data ON plantao (turno, data);
-- @@ Q2b | Q2 | BETWEEN com indice em (turno, data)
SELECT id_plantao, data, duracao_h, id_unidade
FROM plantao
WHERE turno = 'Noite'
  AND data BETWEEN DATE '2025-03-01' AND DATE '2025-03-31';

-- @@ Q2c | Q2 | YEAR()/MONTH() com o mesmo indice (funcao na coluna impede o uso do intervalo)
SELECT id_plantao, data, duracao_h, id_unidade
FROM plantao
WHERE turno = 'Noite'
  AND YEAR(data) = 2025 AND MONTH(data) = 3;
-- @@TEARDOWN Q2c
DROP INDEX idx_plantao_turno_data ON plantao;


-- =====================================================================
-- CONSULTAS COM JUNCAO DE DUAS RELACOES
-- =====================================================================

-- Q3: Plantoes ocorridos em unidades do tipo 'UPA', com o nome da unidade.

-- @@ Q3a | Q3 | JOIN explicito
SELECT p.id_plantao, p.data, p.turno, u.nome AS unidade
FROM plantao p
JOIN unidade u ON u.id_unidade = p.id_unidade
WHERE u.tipo = 'UPA';

-- @@ Q3b | Q3 | Juncao no WHERE, com a ordem das relacoes invertida no FROM
SELECT p.id_plantao, p.data, p.turno, u.nome AS unidade
FROM unidade u, plantao p
WHERE u.id_unidade = p.id_unidade
  AND u.tipo = 'UPA';

-- @@ Q3c | Q3 | Subconsulta IN no WHERE e subconsulta escalar para o nome da unidade
SELECT p.id_plantao, p.data, p.turno,
       (SELECT u.nome FROM unidade u WHERE u.id_unidade = p.id_unidade) AS unidade
FROM plantao p
WHERE p.id_unidade IN (SELECT u.id_unidade FROM unidade u WHERE u.tipo = 'UPA');


-- Q4: Atendimento, remedio, dose e frequencia das prescricoes de remedios de tarja Preta.

-- @@ Q4a | Q4 | JOIN (ordem escolhida pelo otimizador)
SELECT pr.id_atend, r.nome AS remedio, pr.dose, pr.frequencia
FROM prescricao pr
JOIN remedio r ON r.id_remedio = pr.id_remedio
WHERE r.tarja = 'Preta';

-- @@ Q4b | Q4 | STRAIGHT_JOIN forcando a ordem do FROM (prescricao primeiro)
SELECT pr.id_atend, r.nome AS remedio, pr.dose, pr.frequencia
FROM prescricao pr
STRAIGHT_JOIN remedio r ON r.id_remedio = pr.id_remedio
WHERE r.tarja = 'Preta';

-- @@ Q4c | Q4 | Tabela derivada que filtra os remedios de tarja Preta antes da juncao
SELECT pr.id_atend, r.nome AS remedio, pr.dose, pr.frequencia
FROM (SELECT id_remedio, nome FROM remedio WHERE tarja = 'Preta') r
JOIN prescricao pr ON pr.id_remedio = r.id_remedio;


-- Q5: Nome e CPF dos pacientes nascidos antes de 1950 e data/hora dos seus
--     atendimentos de Retorno com diagnostico 'Diabetes'.

-- @@ Q5a | Q5 | JOIN sem indice auxiliar
SELECT pa.nome, pa.cpf, a.data_hora
FROM atendimento a
JOIN paciente pa ON pa.id_paciente = a.id_paciente
WHERE a.tipo = 'Retorno'
  AND a.diagnostico = 'Diabetes'
  AND pa.data_nasc < DATE '1950-01-01';

-- @@SETUP Q5b
CREATE INDEX idx_atend_tipo_diag ON atendimento (tipo, diagnostico);
-- @@ Q5b | Q5 | JOIN com indice em atendimento (tipo, diagnostico)
SELECT pa.nome, pa.cpf, a.data_hora
FROM atendimento a
JOIN paciente pa ON pa.id_paciente = a.id_paciente
WHERE a.tipo = 'Retorno'
  AND a.diagnostico = 'Diabetes'
  AND pa.data_nasc < DATE '1950-01-01';
-- @@TEARDOWN Q5b
DROP INDEX idx_atend_tipo_diag ON atendimento;

-- @@ Q5c | Q5 | STRAIGHT_JOIN forcando comecar por paciente (ordem do FROM invertida)
SELECT pa.nome, pa.cpf, a.data_hora
FROM paciente pa
STRAIGHT_JOIN atendimento a ON a.id_paciente = pa.id_paciente
WHERE a.tipo = 'Retorno'
  AND a.diagnostico = 'Diabetes'
  AND pa.data_nasc < DATE '1950-01-01';


-- =====================================================================
-- CONSULTAS COM JUNCAO DE TRES OU MAIS RELACOES
-- =====================================================================

-- Q6: Atendimentos de Emergencia com diagnostico 'Fratura': paciente,
--     profissional, unidade e data/hora. (5 relacoes)

-- @@ Q6a | Q6 | JOINs encadeados
SELECT a.id_atend, a.data_hora,
       pa.nome AS paciente, pf.nome AS profissional, u.nome AS unidade
FROM atendimento a
JOIN paciente pa     ON pa.id_paciente = a.id_paciente
JOIN profissional pf ON pf.id_prof = a.id_prof
JOIN plantao pl      ON pl.id_plantao = a.id_plantao
JOIN unidade u       ON u.id_unidade = pl.id_unidade
WHERE a.tipo = 'Emergencia'
  AND a.diagnostico = 'Fratura';

-- @@ Q6b | Q6 | Subconsultas escalares correlacionadas no SELECT
SELECT a.id_atend, a.data_hora,
       (SELECT pa.nome FROM paciente pa WHERE pa.id_paciente = a.id_paciente) AS paciente,
       (SELECT pf.nome FROM profissional pf WHERE pf.id_prof = a.id_prof) AS profissional,
       (SELECT u.nome
          FROM plantao pl JOIN unidade u ON u.id_unidade = pl.id_unidade
         WHERE pl.id_plantao = a.id_plantao) AS unidade
FROM atendimento a
WHERE a.tipo = 'Emergencia'
  AND a.diagnostico = 'Fratura';

-- @@SETUP Q6c
CREATE INDEX idx_atend_tipo_diag ON atendimento (tipo, diagnostico);
-- @@ Q6c | Q6 | JOINs encadeados com indice em atendimento (tipo, diagnostico)
SELECT a.id_atend, a.data_hora,
       pa.nome AS paciente, pf.nome AS profissional, u.nome AS unidade
FROM atendimento a
JOIN paciente pa     ON pa.id_paciente = a.id_paciente
JOIN profissional pf ON pf.id_prof = a.id_prof
JOIN plantao pl      ON pl.id_plantao = a.id_plantao
JOIN unidade u       ON u.id_unidade = pl.id_unidade
WHERE a.tipo = 'Emergencia'
  AND a.diagnostico = 'Fratura';
-- @@TEARDOWN Q6c
DROP INDEX idx_atend_tipo_diag ON atendimento;


-- Q7: Pacientes (nome e data de nascimento) atendidos em 2025 por
--     profissionais com especialidade em Pediatria. (3 relacoes)

-- @@ Q7a | Q7 | JOIN com DISTINCT
SELECT DISTINCT p.id_paciente, p.nome, p.data_nasc
FROM paciente p
JOIN atendimento a                ON a.id_paciente = p.id_paciente
JOIN profissional_especialidade e ON e.id_prof = a.id_prof
WHERE e.especialidade = 'Pediatria'
  AND a.data_hora >= TIMESTAMP '2025-01-01 00:00:00'
  AND a.data_hora <  TIMESTAMP '2026-01-01 00:00:00';

-- @@ Q7b | Q7 | Subconsulta com EXISTS
SELECT p.id_paciente, p.nome, p.data_nasc
FROM paciente p
WHERE EXISTS (
    SELECT 1
    FROM atendimento a
    JOIN profissional_especialidade e ON e.id_prof = a.id_prof
    WHERE a.id_paciente = p.id_paciente
      AND e.especialidade = 'Pediatria'
      AND a.data_hora >= TIMESTAMP '2025-01-01 00:00:00'
      AND a.data_hora <  TIMESTAMP '2026-01-01 00:00:00'
);

-- @@ Q7c | Q7 | Subconsulta com IN
SELECT p.id_paciente, p.nome, p.data_nasc
FROM paciente p
WHERE p.id_paciente IN (
    SELECT a.id_paciente
    FROM atendimento a
    JOIN profissional_especialidade e ON e.id_prof = a.id_prof
    WHERE e.especialidade = 'Pediatria'
      AND a.data_hora >= TIMESTAMP '2025-01-01 00:00:00'
      AND a.data_hora <  TIMESTAMP '2026-01-01 00:00:00'
);


-- Q8: Profissionais que atuaram como Coordenador em plantoes noturnos de
--     unidades do tipo UPA em 2025, com a data do plantao e o nome da
--     unidade. Usa o relacionamento M:N "Escalado em" e o seu atributo
--     "funcao". (4 relacoes)

-- @@ Q8a | Q8 | JOINs sem indice auxiliar
SELECT pf.nome AS profissional, pf.cpf, pl.data, u.nome AS unidade
FROM profissional pf
JOIN escalado_em e ON e.id_prof = pf.id_prof
JOIN plantao pl    ON pl.id_plantao = e.id_plantao
JOIN unidade u     ON u.id_unidade = pl.id_unidade
WHERE e.funcao = 'Coordenador'
  AND pl.turno = 'Noite'
  AND pl.data BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
  AND u.tipo = 'UPA';

-- @@SETUP Q8b
CREATE INDEX idx_plantao_turno_data ON plantao (turno, data);
-- @@ Q8b | Q8 | JOINs com indice em plantao (turno, data)
SELECT pf.nome AS profissional, pf.cpf, pl.data, u.nome AS unidade
FROM profissional pf
JOIN escalado_em e ON e.id_prof = pf.id_prof
JOIN plantao pl    ON pl.id_plantao = e.id_plantao
JOIN unidade u     ON u.id_unidade = pl.id_unidade
WHERE e.funcao = 'Coordenador'
  AND pl.turno = 'Noite'
  AND pl.data BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
  AND u.tipo = 'UPA';
-- @@TEARDOWN Q8b
DROP INDEX idx_plantao_turno_data ON plantao;

-- @@ Q8c | Q8 | STRAIGHT_JOIN forcando a ordem unidade -> plantao -> escalado_em -> profissional
SELECT pf.nome AS profissional, pf.cpf, pl.data, u.nome AS unidade
FROM unidade u
STRAIGHT_JOIN plantao pl    ON pl.id_unidade = u.id_unidade
STRAIGHT_JOIN escalado_em e ON e.id_plantao = pl.id_plantao
STRAIGHT_JOIN profissional pf ON pf.id_prof = e.id_prof
WHERE e.funcao = 'Coordenador'
  AND pl.turno = 'Noite'
  AND pl.data BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
  AND u.tipo = 'UPA';


-- =====================================================================
-- CONSULTAS COM AGREGACAO SOBRE JUNCAO
-- =====================================================================

-- Q9: Quantidade de atendimentos por unidade, apenas unidades com mais de
--     30.000 atendimentos, da maior para a menor.

-- @@ Q9a | Q9 | JOIN das tres relacoes e depois GROUP BY
SELECT u.id_unidade, u.nome, COUNT(*) AS total_atendimentos
FROM atendimento a
JOIN plantao p ON p.id_plantao = a.id_plantao
JOIN unidade u ON u.id_unidade = p.id_unidade
GROUP BY u.id_unidade, u.nome
HAVING COUNT(*) > 30000
ORDER BY total_atendimentos DESC;

-- @@ Q9b | Q9 | Agrega primeiro numa tabela derivada e so depois junta com unidade
SELECT u.id_unidade, u.nome, t.total_atendimentos
FROM unidade u
JOIN (SELECT p.id_unidade, COUNT(*) AS total_atendimentos
        FROM atendimento a
        JOIN plantao p ON p.id_plantao = a.id_plantao
       GROUP BY p.id_unidade
      HAVING COUNT(*) > 30000) t ON t.id_unidade = u.id_unidade
ORDER BY t.total_atendimentos DESC;

-- @@ Q9c | Q9 | Subconsulta correlacionada que conta os atendimentos de cada unidade
SELECT id_unidade, nome, total_atendimentos
FROM (SELECT u.id_unidade, u.nome,
             (SELECT COUNT(*)
                FROM atendimento a
                JOIN plantao p ON p.id_plantao = a.id_plantao
               WHERE p.id_unidade = u.id_unidade) AS total_atendimentos
        FROM unidade u) t
WHERE total_atendimentos > 30000
ORDER BY total_atendimentos DESC;


-- Q10: Os 10 remedios mais prescritos em atendimentos de Emergencia, com o
--      principio ativo e o numero de prescricoes.

-- @@ Q10a | Q10 | JOIN das tres relacoes
SELECT r.id_remedio, r.nome, r.principio_ativo, COUNT(*) AS total_prescricoes
FROM prescricao pr
JOIN atendimento a ON a.id_atend = pr.id_atend
JOIN remedio r     ON r.id_remedio = pr.id_remedio
WHERE a.tipo = 'Emergencia'
GROUP BY r.id_remedio, r.nome, r.principio_ativo
ORDER BY total_prescricoes DESC, r.id_remedio
LIMIT 10;

-- @@ Q10b | Q10 | Subconsulta IN no lugar da juncao com atendimento
SELECT r.id_remedio, r.nome, r.principio_ativo, COUNT(*) AS total_prescricoes
FROM prescricao pr
JOIN remedio r ON r.id_remedio = pr.id_remedio
WHERE pr.id_atend IN (SELECT a.id_atend FROM atendimento a WHERE a.tipo = 'Emergencia')
GROUP BY r.id_remedio, r.nome, r.principio_ativo
ORDER BY total_prescricoes DESC, r.id_remedio
LIMIT 10;

-- @@SETUP Q10c
CREATE INDEX idx_atend_tipo ON atendimento (tipo);
-- @@ Q10c | Q10 | JOIN das tres relacoes com indice em atendimento (tipo)
SELECT r.id_remedio, r.nome, r.principio_ativo, COUNT(*) AS total_prescricoes
FROM prescricao pr
JOIN atendimento a ON a.id_atend = pr.id_atend
JOIN remedio r     ON r.id_remedio = pr.id_remedio
WHERE a.tipo = 'Emergencia'
GROUP BY r.id_remedio, r.nome, r.principio_ativo
ORDER BY total_prescricoes DESC, r.id_remedio
LIMIT 10;
-- @@TEARDOWN Q10c
DROP INDEX idx_atend_tipo ON atendimento;
