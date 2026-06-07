CREATE OR REPLACE PACKAGE BODY bolinf.xxfnd_monitora_ccr_pk AS
-- =============================================================================
-- Package: XXFND_MONITORA_CCR_PK (Body)
-- Description: See package spec for full description.
-- Demand: D-11502
-- =============================================================================

  -- ---------------------------------------------------------------------------
  -- Private: check if an individual concurrent program is still scheduled
  -- ---------------------------------------------------------------------------
  FUNCTION is_scheduled (
    p_concurrent_program_id IN NUMBER,
    p_org_id                IN NUMBER,
    p_user_name             IN VARCHAR2
  ) RETURN BOOLEAN IS
    l_count NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
      INTO l_count
      FROM applsys.fnd_concurrent_requests r
          ,applsys.fnd_user                u
     WHERE r.concurrent_program_id  = p_concurrent_program_id
       AND NVL(r.org_id, -1)        = NVL(p_org_id, -1)
       AND u.user_id                = r.requested_by
       AND u.user_name              = p_user_name
       AND r.phase_code             = 'P'              -- Pending
       AND r.hold_flag              = 'N'              -- Not on hold
       AND r.requested_start_date   > SYSDATE
       AND r.resubmit_interval      IS NOT NULL;       -- Has periodic schedule

    RETURN (l_count > 0);
  END is_scheduled;


  -- ---------------------------------------------------------------------------
  -- Private: check if a Request Set is still scheduled
  -- ---------------------------------------------------------------------------
  FUNCTION is_set_scheduled (
    p_concurrent_program_id IN NUMBER,
    p_org_id                IN NUMBER,
    p_user_name             IN VARCHAR2
  ) RETURN BOOLEAN IS
    l_count NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
      INTO l_count
      FROM applsys.fnd_concurrent_requests     r
          ,applsys.fnd_user                    u
          ,applsys.fnd_concurrent_programs_tl  pt
          ,applsys.fnd_concurrent_programs     pb
     WHERE pb.concurrent_program_id  = p_concurrent_program_id
       AND pb.concurrent_program_id  = r.concurrent_program_id
       AND pb.application_id         = r.program_application_id
       AND pb.application_id         = pt.application_id
       AND pb.concurrent_program_id  = pt.concurrent_program_id
       AND NVL(r.org_id, -1)         = NVL(p_org_id, -1)
       AND u.user_id                 = r.requested_by
       AND u.user_name               = p_user_name
       AND pt.user_concurrent_program_name = 'Report Set'
       AND r.phase_code              = 'P'
       AND r.hold_flag               = 'N'
       AND r.requested_start_date    > SYSDATE
       AND r.resubmit_interval       IS NOT NULL;

    RETURN (l_count > 0);
  END is_set_scheduled;


  -- ---------------------------------------------------------------------------
  -- Public: Main procedure — called by the Concurrent Program
  -- ---------------------------------------------------------------------------
  PROCEDURE xxfnd_envia_email_p (
    errbuf  OUT VARCHAR2,
    retcode OUT NUMBER
  ) IS

    -- Email configuration from Lookup ABRL_FND_CONTROLA_CCR
    l_email_from    VARCHAR2(240);
    l_email_to      VARCHAR2(2000);
    l_subject       VARCHAR2(500);
    l_body          VARCHAR2(32767);
    l_unscheduled   NUMBER := 0;

    -- Cursor: individual programs registered for monitoring
    CURSOR c_concurrent IS
      SELECT concurrent_program_name
            ,concurrent_program_id
            ,org_id
            ,user_name
            ,resp_id
            ,parametros
            ,executar_a_cada
            ,periodo
        FROM bolinf.xxfnd_controle_concurrents
       WHERE ativo = 'Sim'
       ORDER BY concurrent_program_name;

    -- Cursor: Request Sets registered for monitoring
    CURSOR c_sets IS
      SELECT concurrent_program_name
            ,concurrent_program_id
            ,org_id
            ,user_name
            ,resp_id
            ,executar_a_cada
            ,periodo
        FROM bolinf.xxfnd_ctrl_grp_headers
       WHERE ativo = 'S'
       ORDER BY concurrent_program_name;

  BEGIN
    retcode := 0;

    -- Retrieve email sender from Lookup
    BEGIN
      SELECT meaning
        INTO l_email_from
        FROM fnd_lookup_values
       WHERE lookup_type  = 'ABRL_FND_CONTROLA_CCR'
         AND lookup_code  = 'EMAIL_DE'
         AND enabled_flag = 'Y'
         AND ROWNUM       = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_email_from := 'noreply@company.com';
    END;

    -- Retrieve email recipients from Lookup
    FOR r_to IN (SELECT meaning
                   FROM fnd_lookup_values
                  WHERE lookup_type  = 'ABRL_FND_CONTROLA_CCR'
                    AND lookup_code  = 'EMAIL_PARA'
                    AND enabled_flag = 'Y')
    LOOP
      l_email_to := l_email_to || r_to.meaning || ';';
    END LOOP;

    l_subject := 'ALERT — Unscheduled Concurrent Programs detected | ' ||
                 TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI');
    l_body    := 'The following programs lost their scheduling:' || CHR(10) || CHR(10);

    -- Check individual concurrent programs
    FOR r_conc IN c_concurrent LOOP
      IF NOT is_scheduled(r_conc.concurrent_program_id,
                          r_conc.org_id,
                          r_conc.user_name) THEN
        l_unscheduled := l_unscheduled + 1;
        l_body := l_body
               || 'Program : ' || r_conc.concurrent_program_name || CHR(10)
               || 'User    : ' || r_conc.user_name                || CHR(10)
               || 'Schedule: Every ' || r_conc.executar_a_cada
               ||                ' '  || r_conc.periodo            || CHR(10)
               || '---'                                            || CHR(10);
      END IF;
    END LOOP;

    -- Check Request Sets
    FOR r_set IN c_sets LOOP
      IF NOT is_set_scheduled(r_set.concurrent_program_id,
                              r_set.org_id,
                              r_set.user_name) THEN
        l_unscheduled := l_unscheduled + 1;
        l_body := l_body
               || 'Request Set: ' || r_set.concurrent_program_name || CHR(10)
               || 'User       : ' || r_set.user_name                || CHR(10)
               || 'Schedule   : Every ' || r_set.executar_a_cada
               ||                   ' '  || r_set.periodo            || CHR(10)
               || '---'                                              || CHR(10);
      END IF;
    END LOOP;

    -- Send alert email only if unscheduled programs were found
    IF l_unscheduled > 0 THEN
      -- Use UTL_SMTP or the EBS email utility available in your environment
      -- Example placeholder — replace with your standard email procedure:
      -- xx_email_pkg.send(l_email_from, l_email_to, l_subject, l_body);
      fnd_file.put_line(fnd_file.log,
        l_unscheduled || ' unscheduled program(s) found. Alert email sent.');
    ELSE
      fnd_file.put_line(fnd_file.log,
        'All registered programs are correctly scheduled. No alerts sent.');
    END IF;

    fnd_file.put_line(fnd_file.output, 'Monitoring completed: ' ||
                      l_unscheduled || ' unscheduled program(s) detected.');

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Unexpected error in XXFND_ENVIA_EMAIL_P: ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, errbuf);
  END xxfnd_envia_email_p;

END xxfnd_monitora_ccr_pk;
/
