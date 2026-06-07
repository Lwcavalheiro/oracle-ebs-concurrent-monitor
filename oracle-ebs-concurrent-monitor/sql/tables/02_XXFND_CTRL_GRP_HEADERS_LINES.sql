-- =============================================================================
-- Table: XXFND_CTRL_GRP_HEADERS
-- Description: Header table for monitored Request Sets (Report Sets).
--              One row per Request Set registered for monitoring.
-- Demand: D-11502
-- Schema: BOLINF
-- =============================================================================

CREATE TABLE bolinf.xxfnd_ctrl_grp_headers (
  cod                     NUMBER,             -- Primary Key (sequential)
  ativo                   VARCHAR2(3),        -- 'S' = active
  concurrent_program_id   NUMBER,             -- Request Set ID
  concurrent_program_name VARCHAR2(240),      -- Request Set name
  org_id                  NUMBER,
  user_name               VARCHAR2(100),      -- user who originally scheduled the set
  resp_id                 NUMBER,
  responsabilidade        VARCHAR2(100),      -- responsibility name
  executar_a_cada         NUMBER,             -- numeric interval (e.g. 1)
  periodo                 VARCHAR2(30),       -- HOURS / DAYS / MONTHS / MINUTES
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_LOGIN       NUMBER,
  CONSTRAINT xxfnd_ctrl_grp_he PRIMARY KEY (cod)
);

-- Grant access to APPS schema
GRANT SELECT, INSERT, UPDATE, DELETE ON bolinf.xxfnd_ctrl_grp_headers TO apps;


-- =============================================================================
-- Table: XXFND_CTRL_GRP_LINES
-- Description: Lines table for monitored Request Sets.
--              Each row represents one individual program within a set,
--              along with its specific parameters.
-- Demand: D-11502
-- Schema: BOLINF
-- =============================================================================

CREATE TABLE bolinf.xxfnd_ctrl_grp_lines (
  cod                     NUMBER,             -- FK to XXFND_CTRL_GRP_HEADERS
  ativo                   VARCHAR2(3),        -- 'S' = active
  concurrent_program_id   NUMBER,             -- individual program ID within the set
  concurrent_program_name VARCHAR2(240),
  org_id                  NUMBER,
  user_name               VARCHAR2(100),
  resp_id                 NUMBER,
  responsabilidade        VARCHAR2(100),
  parametros              VARCHAR2(240),      -- parameters for this program within the set
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_LOGIN       NUMBER,
  CONSTRAINT xxfnd_ctrl_grp_lines_fk
    FOREIGN KEY (cod)
    REFERENCES bolinf.xxfnd_ctrl_grp_headers (cod)
);

-- Grant access to APPS schema
GRANT SELECT, INSERT, UPDATE, DELETE ON bolinf.xxfnd_ctrl_grp_lines TO apps;
