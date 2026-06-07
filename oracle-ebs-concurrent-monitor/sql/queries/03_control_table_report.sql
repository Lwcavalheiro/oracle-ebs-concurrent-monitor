-- =============================================================================
-- Query: Control Table Report — Registered Programs and Sets
-- Description: Reports all entries currently registered in the monitoring
--              control tables, both individual programs and Request Sets.
-- Demand: D-11502
-- Tables: BOLINF.XXFND_CONTROLE_CONCURRENTS,
--         BOLINF.XXFND_CTRL_GRP_HEADERS,
--         BOLINF.XXFND_CTRL_GRP_LINES
-- =============================================================================

-- -----------------------------------------------------------------------
-- 1. Individual concurrent programs registered for monitoring
-- -----------------------------------------------------------------------
SELECT concurrent_program_name  program_name
      ,concurrent_program_id
      ,NVL(TO_CHAR(org_id), 'Null') org_id
      ,user_name
      ,resp_id
      ,parametros                  parameters
      ,executar_a_cada             run_every
      ,periodo                     period
  FROM bolinf.xxfnd_controle_concurrents
 WHERE ativo = 'Sim'
 ORDER BY concurrent_program_name;


-- -----------------------------------------------------------------------
-- 2. Request Sets with their inner programs (header + lines join)
-- -----------------------------------------------------------------------
SELECT xcgh.concurrent_program_id    set_id
      ,xcgh.concurrent_program_name  set_name
      ,xcgh.org_id
      ,xcgh.user_name
      ,xcgh.resp_id
      ,xcgh.responsabilidade         responsibility
      ,xcgh.executar_a_cada          run_every
      ,xcgh.periodo                  period
      ,xcgl.concurrent_program_id    program_id
      ,xcgl.concurrent_program_name  program_name
      ,xcgl.parametros               parameters
  FROM bolinf.xxfnd_ctrl_grp_headers xcgh
      ,bolinf.xxfnd_ctrl_grp_lines   xcgl
 WHERE xcgh.cod   = xcgl.cod
   AND xcgh.ativo = 'S'
 ORDER BY xcgh.concurrent_program_name;
