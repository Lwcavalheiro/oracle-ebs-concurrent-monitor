-- =============================================================================
-- Table: XXFND_CONTROLE_CONCURRENTS
-- Description: Stores individual Concurrent Programs registered for monitoring.
--              Each row represents one program that must remain scheduled.
-- Demand: D-11502
-- Schema: BOLINF
-- =============================================================================

CREATE TABLE bolinf.xxfnd_controle_concurrents (
  ativo                   VARCHAR2(3),        -- 'Sim' = active monitoring
  concurrent_program_id   NUMBER,
  concurrent_program_name VARCHAR2(240),
  org_id                  NUMBER,
  user_name               VARCHAR2(100),      -- user who originally scheduled the program
  resp_id                 NUMBER,
  responsabilidade        VARCHAR2(100),      -- responsibility name
  parametros              VARCHAR2(240),      -- program parameters
  executar_a_cada         NUMBER,             -- numeric interval (e.g. 1)
  periodo                 VARCHAR2(30),       -- HOURS / DAYS / MONTHS / MINUTES
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_LOGIN       NUMBER
);

-- Grant access to APPS schema
GRANT SELECT, INSERT, UPDATE, DELETE ON bolinf.xxfnd_controle_concurrents TO apps;
