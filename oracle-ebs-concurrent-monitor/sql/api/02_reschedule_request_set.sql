-- =============================================================================
-- API: Reschedule Request Set (Report Set)
-- Description: Uses FND_SUBMIT to reschedule a full Request Set, submitting
--              each inner program with its original parameters.
--              Parameters are read from a prior execution via FND_RUN_REQUESTS
--              to guarantee the same configuration is preserved.
-- Demand: D-11502
-- Oracle APIs: FND_GLOBAL.APPS_INITIALIZE, FND_SUBMIT
-- =============================================================================

DECLARE
   l_success            BOOLEAN;
   l_request_id         NUMBER;
   l_set_repeat_options BOOLEAN;

   -- Cursor reads each program and its parameters from the Request Set
   -- using FND_RUN_REQUESTS, joining from a reference execution (model run)
   CURSOR c_rset (p_parent_request_id NUMBER) IS
   SELECT fcp.concurrent_program_name
         ,rss.stage_name
         ,(SELECT application_short_name
             FROM apps.fnd_application fa
            WHERE fa.application_id = fcp.application_id) application_short_name
         ,fcr_conc.argument1,  fcr_conc.argument2,  fcr_conc.argument3
         ,fcr_conc.argument4,  fcr_conc.argument5,  fcr_conc.argument6
         ,fcr_conc.argument7,  fcr_conc.argument8,  fcr_conc.argument9
         ,fcr_conc.argument10, fcr_conc.argument11, fcr_conc.argument12
         ,fcr_conc.argument13, fcr_conc.argument14, fcr_conc.argument15
         ,fcr_conc.argument16, fcr_conc.argument17, fcr_conc.argument18
         ,fcr_conc.argument19, fcr_conc.argument20
         ,fcr_conc.number_of_arguments
     FROM apps.fnd_request_set_programs  rs
         ,fnd_concurrent_programs        fcp
         ,apps.fnd_req_set_stages_form_v rss
         ,fnd_concurrent_requests        fcr_rset
         ,fnd_concurrent_requests        fcr_conc
    WHERE rs.set_application_id     = fcr_rset.argument1
      AND rs.request_set_id         = fcr_rset.argument2
      AND rs.request_set_stage_id   = fcr_rset.argument3
      AND rs.concurrent_program_id  = fcp.concurrent_program_id
      AND rs.program_application_id = fcp.application_id
      AND rss.set_application_id    = rs.set_application_id
      AND rss.request_set_id        = rs.request_set_id
      AND rss.request_set_stage_id  = rs.request_set_stage_id
      AND fcr_rset.request_id       = fcr_conc.parent_request_id
      AND fcr_rset.parent_request_id = p_parent_request_id
    ORDER BY rss.display_sequence, rs.sequence;

   r_rset c_rset%ROWTYPE;

BEGIN
   FND_GLOBAL.APPS_INITIALIZE(
     user_id      => :v_user_id
    ,resp_id      => :v_resp_id
    ,resp_appl_id => :v_resp_appl_id
   );

   -- Set periodic schedule for the Request Set
   l_set_repeat_options := apps.fnd_submit.set_repeat_options(
     repeat_time      => NULL
    ,repeat_interval  => :v_run_every   -- EXECUTAR_A_CADA from control table
    ,repeat_unit      => :v_period      -- PERIODO from control table
    ,repeat_type      => 'START'
    ,repeat_end_time  => NULL
   );

   IF NOT l_set_repeat_options THEN
      fnd_file.put_line(fnd_file.log, 'Error setting repeat options for the Request Set');
   ELSE
      -- Identify the Request Set to submit
      l_success := apps.fnd_submit.set_request_set(:v_app_short_name, :v_request_set_name);

      IF l_success THEN
         -- Submit each inner program with its original parameters
         FOR r_rset IN c_rset(:v_reference_request_id)
         LOOP
            -- FND_SUBMIT requires chr(0) as terminator after the last argument
            IF    r_rset.number_of_arguments = 0  THEN r_rset.argument1  := chr(0);
            ELSIF r_rset.number_of_arguments = 1  THEN r_rset.argument2  := chr(0);
            ELSIF r_rset.number_of_arguments = 2  THEN r_rset.argument3  := chr(0);
            ELSIF r_rset.number_of_arguments = 3  THEN r_rset.argument4  := chr(0);
            ELSIF r_rset.number_of_arguments = 4  THEN r_rset.argument5  := chr(0);
            ELSIF r_rset.number_of_arguments = 5  THEN r_rset.argument6  := chr(0);
            ELSIF r_rset.number_of_arguments = 6  THEN r_rset.argument7  := chr(0);
            ELSIF r_rset.number_of_arguments = 7  THEN r_rset.argument8  := chr(0);
            ELSIF r_rset.number_of_arguments = 8  THEN r_rset.argument9  := chr(0);
            ELSIF r_rset.number_of_arguments = 9  THEN r_rset.argument10 := chr(0);
            ELSIF r_rset.number_of_arguments = 10 THEN r_rset.argument11 := chr(0);
            END IF;

            l_success := apps.fnd_submit.submit_program(
              r_rset.application_short_name
             ,r_rset.concurrent_program_name
             ,r_rset.stage_name
             ,r_rset.argument1,  r_rset.argument2,  r_rset.argument3
             ,r_rset.argument4,  r_rset.argument5,  r_rset.argument6
             ,r_rset.argument7,  r_rset.argument8,  r_rset.argument9
             ,r_rset.argument10, r_rset.argument11, r_rset.argument12
             ,r_rset.argument13, r_rset.argument14, r_rset.argument15
             ,r_rset.argument16, r_rset.argument17, r_rset.argument18
             ,r_rset.argument19, r_rset.argument20
            );

            IF NOT l_success THEN
               fnd_file.put_line(fnd_file.log,
                 'Error on submit_program: ' || r_rset.concurrent_program_name);
               EXIT;
            END IF;
         END LOOP;
      END IF;

      -- Commit the full Request Set submission
      IF l_success THEN
         l_request_id := apps.fnd_submit.submit_set(NULL, FALSE);
         COMMIT;
         fnd_file.put_line(fnd_file.log,
           'Request Set rescheduled successfully. Request ID: ' || l_request_id);
      END IF;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
        'Error rescheduling Request Set: ' || SQLERRM);
      ROLLBACK;
END;
