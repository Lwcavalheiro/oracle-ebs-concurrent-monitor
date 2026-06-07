CREATE OR REPLACE PACKAGE bolinf.xxfnd_monitora_ccr_pk AS
-- =============================================================================
-- Package: XXFND_MONITORA_CCR_PK (Specification)
-- Description: Monitoring engine for scheduled Concurrent Programs and
--              Request Sets. Checks whether programs registered in the
--              control tables still have an active schedule in
--              FND_CONCURRENT_REQUESTS. Sends an email alert for any
--              program found without scheduling.
--
-- Concurrent Program executable: ABRL_FND_CTRL_PROG_CCR
-- Email recipients Lookup: ABRL_FND_CONTROLA_CCR
-- Demand: D-11502
-- =============================================================================

  -- Main procedure called by the Concurrent Program.
  -- Executable path: BOLINF.XXFND_MONITORA_CCR_PK.XXFND_ENVIA_EMAIL_P
  PROCEDURE xxfnd_envia_email_p(
    errbuf  OUT VARCHAR2,
    retcode OUT NUMBER
  );

END xxfnd_monitora_ccr_pk;
/
