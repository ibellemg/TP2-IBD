-- =====================================================================
-- TP2 - Introducao a Banco de Dados - Grupo 5
-- Gestao de medicos e plantoes
-- Esquema relacional (mapeado do diagrama ER) - SGBD: MySQL 8.0.16+
-- =====================================================================
-- Restricoes de integridade usadas:
--   PRIMARY KEY  - chave de cada entidade / chave composta dos M:N
--   FOREIGN KEY  - relacionamentos (com ON DELETE / ON UPDATE)
--   NOT NULL     - atributos obrigatorios e participacao total
--   UNIQUE       - chaves candidatas (cpf, nome da unidade...)
--   CHECK        - dominio dos atributos (valores validos)
-- Regras que envolvem mais de uma tabela ficam nos gatilhos
-- (04_gatilhos.sql).
--
-- Observacao: no MySQL, um "REFERENCES" escrito na propria linha da
-- coluna e ignorado. Por isso as FKs estao declaradas no fim da tabela.
-- O InnoDB cria automaticamente um indice para cada FK.
-- =====================================================================

DROP DATABASE IF EXISTS tp2_plantoes;
CREATE DATABASE tp2_plantoes CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE tp2_plantoes;

-- ---------------------------------------------------------------------
-- Entidade Unidade
-- ---------------------------------------------------------------------
CREATE TABLE unidade (
    id_unidade INT          NOT NULL,
    nome       VARCHAR(100) NOT NULL,
    tipo       VARCHAR(30)  NOT NULL,
    CONSTRAINT pk_unidade      PRIMARY KEY (id_unidade),
    CONSTRAINT uq_unidade_nome UNIQUE (nome),
    CONSTRAINT ck_unidade_tipo CHECK (tipo IN ('Hospital', 'UPA', 'Policlinica', 'Maternidade'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entidade Profissional
-- ---------------------------------------------------------------------
CREATE TABLE profissional (
    id_prof       INT          NOT NULL,
    cpf           CHAR(11)     NOT NULL,
    nome          VARCHAR(100) NOT NULL,
    cargo         VARCHAR(40)  NOT NULL,
    carga_horaria INT          NOT NULL,            -- horas semanais
    CONSTRAINT pk_profissional     PRIMARY KEY (id_prof),
    CONSTRAINT uq_profissional_cpf UNIQUE (cpf),     -- chave candidata
    CONSTRAINT ck_profissional_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
    CONSTRAINT ck_profissional_cargo CHECK (cargo IN ('Medico', 'Enfermeiro',
                                                      'Tecnico de Enfermagem', 'Fisioterapeuta')),
    CONSTRAINT ck_profissional_carga CHECK (carga_horaria BETWEEN 12 AND 60)
) ENGINE=InnoDB;

-- Atributo multivalorado {especialidades}
CREATE TABLE profissional_especialidade (
    id_prof       INT         NOT NULL,
    especialidade VARCHAR(60) NOT NULL,
    CONSTRAINT pk_prof_esp PRIMARY KEY (id_prof, especialidade),
    CONSTRAINT fk_esp_prof FOREIGN KEY (id_prof) REFERENCES profissional (id_prof)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entidade Plantao
-- "Ocorre em" (Plantao N : 1 Unidade, participacao total) -> FK NOT NULL
-- ---------------------------------------------------------------------
CREATE TABLE plantao (
    id_plantao INT         NOT NULL,
    data       DATE        NOT NULL,
    duracao_h  INT         NOT NULL,
    turno      VARCHAR(10) NOT NULL,
    id_unidade INT         NOT NULL,                -- Ocorre em
    CONSTRAINT pk_plantao         PRIMARY KEY (id_plantao),
    CONSTRAINT uq_plantao         UNIQUE (id_unidade, data, turno),  -- 1 plantao por unidade/dia/turno
    CONSTRAINT fk_plantao_unidade FOREIGN KEY (id_unidade) REFERENCES unidade (id_unidade)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_plantao_turno   CHECK (turno IN ('Manha', 'Tarde', 'Noite')),
    CONSTRAINT ck_plantao_duracao CHECK ((turno IN ('Manha', 'Tarde') AND duracao_h = 6)
                                         OR (turno = 'Noite' AND duracao_h = 12))
) ENGINE=InnoDB;

-- Relacionamento "Escalado em" (Profissional M : N Plantao) com o atributo "funcao"
CREATE TABLE escalado_em (
    id_prof    INT         NOT NULL,
    id_plantao INT         NOT NULL,
    funcao     VARCHAR(40) NOT NULL,
    CONSTRAINT pk_escalado_em  PRIMARY KEY (id_prof, id_plantao),
    CONSTRAINT fk_esc_prof     FOREIGN KEY (id_prof) REFERENCES profissional (id_prof)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_esc_plantao  FOREIGN KEY (id_plantao) REFERENCES plantao (id_plantao)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_esc_funcao   CHECK (funcao IN ('Coordenador', 'Plantonista', 'Assistencia'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entidade Paciente
-- ---------------------------------------------------------------------
CREATE TABLE paciente (
    id_paciente INT          NOT NULL,
    cpf         CHAR(11)     NOT NULL,
    nome        VARCHAR(100) NOT NULL,
    data_nasc   DATE         NOT NULL,
    CONSTRAINT pk_paciente      PRIMARY KEY (id_paciente),
    CONSTRAINT uq_paciente_cpf  UNIQUE (cpf),         -- chave candidata
    CONSTRAINT ck_paciente_cpf  CHECK (cpf REGEXP '^[0-9]{11}$'),
    CONSTRAINT ck_paciente_nasc CHECK (data_nasc >= '1900-01-01')
) ENGINE=InnoDB;

-- Atributo multivalorado {contatos}
CREATE TABLE paciente_contato (
    id_paciente INT         NOT NULL,
    contato     VARCHAR(80) NOT NULL,
    CONSTRAINT pk_paciente_contato PRIMARY KEY (id_paciente, contato),
    CONSTRAINT fk_contato_paciente FOREIGN KEY (id_paciente) REFERENCES paciente (id_paciente)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entidade Remedio
-- ---------------------------------------------------------------------
CREATE TABLE remedio (
    id_remedio      INT          NOT NULL,
    nome            VARCHAR(100) NOT NULL,
    fabricante      VARCHAR(100) NOT NULL,
    principio_ativo VARCHAR(100) NOT NULL,
    tarja           VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_remedio       PRIMARY KEY (id_remedio),
    CONSTRAINT uq_remedio       UNIQUE (nome, fabricante),
    CONSTRAINT ck_remedio_tarja CHECK (tarja IN ('Sem tarja', 'Vermelha', 'Preta'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entidade Atendimento
-- "Realiza", "Recebe" e "Ocorre durante" (1:N, participacao total de
-- Atendimento) -> tres FKs NOT NULL
-- ---------------------------------------------------------------------
CREATE TABLE atendimento (
    id_atend    INT          NOT NULL,
    data_hora   DATETIME     NOT NULL,
    tipo        VARCHAR(30)  NOT NULL,
    diagnostico VARCHAR(100) NOT NULL,
    id_prof     INT          NOT NULL,   -- Realiza
    id_paciente INT          NOT NULL,   -- Recebe
    id_plantao  INT          NOT NULL,   -- Ocorre durante
    CONSTRAINT pk_atendimento    PRIMARY KEY (id_atend),
    CONSTRAINT fk_atend_prof     FOREIGN KEY (id_prof) REFERENCES profissional (id_prof)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_atend_paciente FOREIGN KEY (id_paciente) REFERENCES paciente (id_paciente)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_atend_plantao  FOREIGN KEY (id_plantao) REFERENCES plantao (id_plantao)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_atend_tipo     CHECK (tipo IN ('Consulta', 'Emergencia', 'Retorno', 'Procedimento'))
) ENGINE=InnoDB;

-- Relacionamento "Prescreve" (Atendimento M : N Remedio) com "dose" e "frequencia"
CREATE TABLE prescricao (
    id_atend   INT         NOT NULL,
    id_remedio INT         NOT NULL,
    dose       VARCHAR(30) NOT NULL,
    frequencia VARCHAR(30) NOT NULL,
    CONSTRAINT pk_prescricao    PRIMARY KEY (id_atend, id_remedio),
    CONSTRAINT fk_presc_atend   FOREIGN KEY (id_atend) REFERENCES atendimento (id_atend)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_presc_remedio FOREIGN KEY (id_remedio) REFERENCES remedio (id_remedio)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
