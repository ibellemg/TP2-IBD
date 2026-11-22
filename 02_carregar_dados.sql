-- =====================================================================
-- TP2 - Grupo 5 - Carga dos CSVs gerados por gerar_dados.py (MySQL 8.x)
-- =====================================================================
-- ANTES DE RODAR (so uma vez):
--  1) No Workbench: Database > Manage Connections > sua conexao > aba
--     Advanced > campo "Others": acrescente a linha  OPT_LOCAL_INFILE=1
--     Feche e abra a conexao de novo.
--  2) Rode o comando abaixo uma vez (habilita a carga de arquivos locais):
SET GLOBAL local_infile = 1;
--  3) Troque /caminho/para/dados/ pelo caminho completo da pasta "dados"
--     (ex.: /home/isa/tp2_mysql/dados/). No Windows, use C:/.../dados/ com barras normais.
--     Dica: no Workbench, Ctrl+H (Find & Replace) troca todos de uma vez.
-- A ordem das cargas respeita as chaves estrangeiras.
-- =====================================================================

USE tp2_plantoes;

LOAD DATA LOCAL INFILE '/caminho/para/dados/unidade.csv'
INTO TABLE unidade CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_unidade, nome, tipo);

LOAD DATA LOCAL INFILE '/caminho/para/dados/profissional.csv'
INTO TABLE profissional CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_prof, cpf, nome, cargo, carga_horaria);

LOAD DATA LOCAL INFILE '/caminho/para/dados/profissional_especialidade.csv'
INTO TABLE profissional_especialidade CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_prof, especialidade);

LOAD DATA LOCAL INFILE '/caminho/para/dados/plantao.csv'
INTO TABLE plantao CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_plantao, data, duracao_h, turno, id_unidade);

LOAD DATA LOCAL INFILE '/caminho/para/dados/escalado_em.csv'
INTO TABLE escalado_em CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_prof, id_plantao, funcao);

LOAD DATA LOCAL INFILE '/caminho/para/dados/paciente.csv'
INTO TABLE paciente CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_paciente, cpf, nome, data_nasc);

LOAD DATA LOCAL INFILE '/caminho/para/dados/paciente_contato.csv'
INTO TABLE paciente_contato CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_paciente, contato);

LOAD DATA LOCAL INFILE '/caminho/para/dados/remedio.csv'
INTO TABLE remedio CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_remedio, nome, fabricante, principio_ativo, tarja);

LOAD DATA LOCAL INFILE '/caminho/para/dados/atendimento.csv'
INTO TABLE atendimento CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_atend, data_hora, tipo, diagnostico, id_prof, id_paciente, id_plantao);

LOAD DATA LOCAL INFILE '/caminho/para/dados/prescricao.csv'
INTO TABLE prescricao CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES (id_atend, id_remedio, dose, frequencia);

-- Atualiza as estatisticas usadas pelo otimizador
ANALYZE TABLE unidade, profissional, profissional_especialidade, plantao, escalado_em,
              paciente, paciente_contato, remedio, atendimento, prescricao;

-- Conferencia rapida dos volumes carregados
SELECT 'unidade' AS tabela, COUNT(*) AS linhas FROM unidade
UNION ALL SELECT 'profissional', COUNT(*) FROM profissional
UNION ALL SELECT 'profissional_especialidade', COUNT(*) FROM profissional_especialidade
UNION ALL SELECT 'plantao', COUNT(*) FROM plantao
UNION ALL SELECT 'escalado_em', COUNT(*) FROM escalado_em
UNION ALL SELECT 'paciente', COUNT(*) FROM paciente
UNION ALL SELECT 'paciente_contato', COUNT(*) FROM paciente_contato
UNION ALL SELECT 'remedio', COUNT(*) FROM remedio
UNION ALL SELECT 'atendimento', COUNT(*) FROM atendimento
UNION ALL SELECT 'prescricao', COUNT(*) FROM prescricao;
