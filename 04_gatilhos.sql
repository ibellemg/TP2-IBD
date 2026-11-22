-- =====================================================================
-- TP2 - Grupo 5 - Regras de negocio que o diagrama ER nao expressa
-- (gatilhos, funcao e procedimentos armazenados) - MySQL 8.x
-- =====================================================================
-- Rodar DEPOIS da carga dos dados (os dados gerados ja respeitam todas
-- as regras). Pode ser rodado de novo a qualquer momento: ele apaga e
-- recria tudo.  Terminal:  mysql -u root -p < 04_gatilhos.sql
--
-- Regras e TODAS as operacoes que poderiam quebra-las:
--  R1. Quem realiza um atendimento precisa estar escalado no plantao.
--      - INSERT/UPDATE em atendimento ..... trg_atendimento_ins / _upd
--      - DELETE/UPDATE em escalado_em ..... trg_escalado_del / _upd
--  R2. A data/hora do atendimento precisa estar no horario do plantao
--      (Manha 07h-13h, Tarde 13h-19h, Noite 19h-07h do dia seguinte).
--      - INSERT/UPDATE em atendimento ..... trg_atendimento_ins / _upd
--      - UPDATE em plantao (data, turno, duracao) ..... trg_plantao_upd
--  R3. So medicos podem prescrever remedios.
--      - INSERT/UPDATE em prescricao ...... trg_prescricao_ins / _upd
--      - UPDATE em atendimento (troca do profissional) ... trg_atendimento_upd
--      - UPDATE em profissional (troca de cargo) ......... trg_profissional_upd
--  R4. Todo plantao tem pelo menos um profissional escalado.
--      - DELETE/UPDATE em escalado_em ..... trg_escalado_del / _upd
--      - INSERT em plantao: o MySQL nao verifica restricoes no fim da
--        transacao, entao nao ha como barrar um plantao criado sem
--        escala. O procedimento criar_plantao() e a forma correta de
--        criar um plantao: insere o plantao e o coordenador juntos,
--        numa transacao.
--
-- Observacao: acoes em cascata das chaves estrangeiras (ON DELETE/UPDATE
-- CASCADE) nao disparam gatilhos no MySQL. Por isso apagar um plantao
-- inteiro continua possivel (a escala vai junto), desde que ele nao
-- tenha atendimentos (atendimento -> plantao e RESTRICT).
-- =====================================================================

USE tp2_plantoes;

DROP FUNCTION  IF EXISTS inicio_turno;
DROP PROCEDURE IF EXISTS validar_atendimento;
DROP PROCEDURE IF EXISTS criar_plantao;
DROP TRIGGER IF EXISTS trg_atendimento_ins;
DROP TRIGGER IF EXISTS trg_atendimento_upd;
DROP TRIGGER IF EXISTS trg_prescricao_ins;
DROP TRIGGER IF EXISTS trg_prescricao_upd;
DROP TRIGGER IF EXISTS trg_escalado_del;
DROP TRIGGER IF EXISTS trg_escalado_upd;
DROP TRIGGER IF EXISTS trg_plantao_upd;
DROP TRIGGER IF EXISTS trg_profissional_upd;

DELIMITER $$

-- Inicio do turno de um plantao (usado por R2)
CREATE FUNCTION inicio_turno(p_data DATE, p_turno VARCHAR(10))
RETURNS DATETIME
DETERMINISTIC NO SQL
BEGIN
    RETURN TIMESTAMP(p_data, CASE p_turno WHEN 'Manha' THEN '07:00:00'
                                          WHEN 'Tarde' THEN '13:00:00'
                                          ELSE '19:00:00' END);
END$$

-- R1 e R2 para um atendimento (chamado nos gatilhos de atendimento)
CREATE PROCEDURE validar_atendimento(IN p_id_prof INT, IN p_id_plantao INT, IN p_data_hora DATETIME)
BEGIN
    DECLARE v_inicio DATETIME;
    DECLARE v_fim    DATETIME;

    IF NOT EXISTS (SELECT 1 FROM escalado_em e
                   WHERE e.id_prof = p_id_prof AND e.id_plantao = p_id_plantao) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R1: o profissional nao esta escalado neste plantao';
    END IF;

    SELECT inicio_turno(p.data, p.turno),
           inicio_turno(p.data, p.turno) + INTERVAL p.duracao_h HOUR
      INTO v_inicio, v_fim
      FROM plantao p
     WHERE p.id_plantao = p_id_plantao;

    IF p_data_hora < v_inicio OR p_data_hora >= v_fim THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R2: a data/hora do atendimento esta fora do horario do plantao';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- atendimento: R1, R2 e R3
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_atendimento_ins
BEFORE INSERT ON atendimento
FOR EACH ROW
BEGIN
    CALL validar_atendimento(NEW.id_prof, NEW.id_plantao, NEW.data_hora);
END$$

CREATE TRIGGER trg_atendimento_upd
BEFORE UPDATE ON atendimento
FOR EACH ROW
BEGIN
    CALL validar_atendimento(NEW.id_prof, NEW.id_plantao, NEW.data_hora);

    -- R3: um atendimento com prescricao nao pode passar para um nao medico
    IF NEW.id_prof <> OLD.id_prof
       AND (SELECT pf.cargo FROM profissional pf WHERE pf.id_prof = NEW.id_prof) <> 'Medico'
       AND EXISTS (SELECT 1 FROM prescricao pr WHERE pr.id_atend = OLD.id_atend) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R3: o atendimento tem prescricao e so pode ser atribuido a um medico';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- prescricao: R3
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_prescricao_ins
BEFORE INSERT ON prescricao
FOR EACH ROW
BEGIN
    IF (SELECT pf.cargo
          FROM atendimento a JOIN profissional pf ON pf.id_prof = a.id_prof
         WHERE a.id_atend = NEW.id_atend) <> 'Medico' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R3: somente medicos podem prescrever remedios';
    END IF;
END$$

CREATE TRIGGER trg_prescricao_upd
BEFORE UPDATE ON prescricao
FOR EACH ROW
BEGIN
    IF (SELECT pf.cargo
          FROM atendimento a JOIN profissional pf ON pf.id_prof = a.id_prof
         WHERE a.id_atend = NEW.id_atend) <> 'Medico' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R3: somente medicos podem prescrever remedios';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- profissional: R3 (um medico que ja prescreveu nao pode mudar de cargo)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_profissional_upd
BEFORE UPDATE ON profissional
FOR EACH ROW
BEGIN
    IF OLD.cargo = 'Medico' AND NEW.cargo <> 'Medico'
       AND EXISTS (SELECT 1 FROM atendimento a JOIN prescricao pr ON pr.id_atend = a.id_atend
                   WHERE a.id_prof = OLD.id_prof) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R3: o profissional tem prescricoes e precisa continuar como medico';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- escalado_em: R1 e R4
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_escalado_del
BEFORE DELETE ON escalado_em
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM atendimento a
               WHERE a.id_prof = OLD.id_prof AND a.id_plantao = OLD.id_plantao) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R1: o profissional ja realizou atendimentos neste plantao';
    END IF;
    IF (SELECT COUNT(*) FROM escalado_em e WHERE e.id_plantao = OLD.id_plantao) <= 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R4: o plantao ficaria sem nenhum profissional escalado';
    END IF;
END$$

CREATE TRIGGER trg_escalado_upd
BEFORE UPDATE ON escalado_em
FOR EACH ROW
BEGIN
    IF (NEW.id_prof <> OLD.id_prof OR NEW.id_plantao <> OLD.id_plantao)
       AND EXISTS (SELECT 1 FROM atendimento a
                   WHERE a.id_prof = OLD.id_prof AND a.id_plantao = OLD.id_plantao) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R1: o profissional ja realizou atendimentos neste plantao';
    END IF;
    IF NEW.id_plantao <> OLD.id_plantao
       AND (SELECT COUNT(*) FROM escalado_em e WHERE e.id_plantao = OLD.id_plantao) <= 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R4: o plantao ficaria sem nenhum profissional escalado';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- plantao: R2 (mudar data, turno ou duracao nao pode deixar atendimentos
-- fora do novo horario)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_plantao_upd
BEFORE UPDATE ON plantao
FOR EACH ROW
BEGIN
    DECLARE v_inicio DATETIME;
    DECLARE v_fim    DATETIME;

    IF NEW.data <> OLD.data OR NEW.turno <> OLD.turno OR NEW.duracao_h <> OLD.duracao_h THEN
        SET v_inicio = inicio_turno(NEW.data, NEW.turno);
        SET v_fim    = v_inicio + INTERVAL NEW.duracao_h HOUR;
        IF EXISTS (SELECT 1 FROM atendimento a
                   WHERE a.id_plantao = OLD.id_plantao
                     AND (a.data_hora < v_inicio OR a.data_hora >= v_fim)) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'R2: a mudanca deixaria atendimentos fora do horario do plantao';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- R4: forma correta de criar um plantao (plantao + coordenador juntos)
-- ---------------------------------------------------------------------
CREATE PROCEDURE criar_plantao(IN p_id_plantao INT, IN p_data DATE, IN p_turno VARCHAR(10),
                               IN p_id_unidade INT, IN p_id_coordenador INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    INSERT INTO plantao (id_plantao, data, duracao_h, turno, id_unidade)
    VALUES (p_id_plantao, p_data, IF(p_turno = 'Noite', 12, 6), p_turno, p_id_unidade);
    INSERT INTO escalado_em (id_prof, id_plantao, funcao)
    VALUES (p_id_coordenador, p_id_plantao, 'Coordenador');
    COMMIT;
END$$

DELIMITER ;

-- =====================================================================
-- DEMONSTRACAO (opcional, bom para o video). Cada bloco abaixo deve ser
-- RECUSADO com a mensagem da regra. Para testar, copie o bloco para uma
-- aba nova do Workbench, tire o "-- " do inicio das linhas e execute.
-- Nenhum deles altera o banco (sao todos recusados).
-- =====================================================================
-- R1 (INSERT): atendimento por um profissional que nao esta no plantao
-- INSERT INTO atendimento VALUES (9999999, '2025-01-01 08:00:00', 'Consulta', 'Gripe', 1, 1,
--     (SELECT id_plantao FROM escalado_em WHERE id_plantao NOT IN
--         (SELECT id_plantao FROM escalado_em WHERE id_prof = 1) LIMIT 1));
--
-- R1 (DELETE): tirar da escala quem atendeu no plantao
-- DELETE FROM escalado_em
--  WHERE (id_prof, id_plantao) IN (SELECT id_prof, id_plantao FROM atendimento WHERE id_atend = 1);
--
-- R2 (INSERT): atendimento as 03h num plantao da manha
-- INSERT INTO atendimento
--     SELECT 9999999, TIMESTAMP(p.data, '03:00:00'), 'Consulta', 'Gripe', e.id_prof, 1, p.id_plantao
--       FROM plantao p JOIN escalado_em e ON e.id_plantao = p.id_plantao
--      WHERE p.turno = 'Manha' LIMIT 1;
--
-- R2 (UPDATE em plantao): mudar a data de um plantao que ja tem atendimentos
-- UPDATE plantao SET data = data + INTERVAL 1 DAY
--  WHERE id_plantao = (SELECT id_plantao FROM atendimento WHERE id_atend = 1);
--
-- R3 (INSERT): prescricao num atendimento feito por um enfermeiro
-- INSERT INTO prescricao
--     SELECT a.id_atend, 1, '1 comprimido', '8/8h'
--       FROM atendimento a JOIN profissional pf ON pf.id_prof = a.id_prof
--      WHERE pf.cargo = 'Enfermeiro' LIMIT 1;
--
-- R3 (UPDATE em atendimento): passar um atendimento com prescricao para
-- um enfermeiro escalado no mesmo plantao (assim R1 nao interfere)
-- SELECT a.id_atend, e.id_prof INTO @atend, @enf
--   FROM atendimento a
--   JOIN prescricao pr  ON pr.id_atend = a.id_atend
--   JOIN escalado_em e  ON e.id_plantao = a.id_plantao
--   JOIN profissional pf ON pf.id_prof = e.id_prof
--  WHERE pf.cargo = 'Enfermeiro' LIMIT 1;
-- UPDATE atendimento SET id_prof = @enf WHERE id_atend = @atend;
--
-- R4 (DELETE): criar um plantao pelo procedimento e tentar tirar o unico
-- escalado (o plantao de teste e apagado no final)
-- CALL criar_plantao(9999999, '2026-01-01', 'Manha', 1,
--      (SELECT id_prof FROM profissional WHERE cargo = 'Medico' LIMIT 1));
-- DELETE FROM escalado_em WHERE id_plantao = 9999999;      -- recusado (R4)
-- DELETE FROM plantao WHERE id_plantao = 9999999;          -- limpeza (a escala vai em cascata)
--
-- CHECK: cargo invalido
-- INSERT INTO profissional VALUES (999999, '12345678909', 'Teste', 'Dentista', 40);
