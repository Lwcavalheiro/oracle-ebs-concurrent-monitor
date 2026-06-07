-- =============================================================================
-- API: Reschedule Individual Concurrent Program
-- Description: Uses FND_REQUEST.SET_REPEAT_OPTIONS + FND_REQUEST.SUBMIT_REQUEST
--              to reschedule a concurrent program with periodic recurrence.
--              Called by the "Reschedule" button on Tab 2 of XXFNDCTRLCCR Forms.
--              Parameters are read from XXFND_CONTROLE_CONCURRENTS.
-- Demand: D-11502
-- Oracle APIs: FND_GLOBAL.APPS_INITIALIZE, FND_REQUEST
-- =============================================================================

DECLARE
   l_request_id         NUMBER;
   l_set_repeat_options BOOLEAN;
BEGIN
   -- Initialize Oracle Apps session with the user/responsibility stored in the
   -- control table for this program
   FND_GLOBAL.APPS_INITIALIZE(
     user_id      => :v_user_id         -- USER_ID from control table
    ,resp_id      => :v_resp_id         -- RESP_ID from control table
    ,resp_appl_id => :v_resp_appl_id
   );

   -- Set the periodic schedule using values from the control table
   l_set_repeat_options := apps.fnd_request.set_repeat_options(
     repeat_time      => NULL
    ,repeat_interval  => :v_run_every   -- EXECUTAR_A_CADA column (e.g. 1)
    ,repeat_unit      => :v_period      -- PERIODO column (HOURS/DAYS/MONTHS/MINUTES)
    ,repeat_type      => 'START'        -- interval counted from start of prior run
    ,repeat_end_time  => NULL           -- no end date
    ,increment_dates  => NULL
   );

   IF NOT l_set_repeat_options THEN
      fnd_file.put_line(fnd_file.log,
        'Error setting repeat options for: ' || :v_concurrent_program_name);
   ELSE
      -- Submit the concurrent program with its registered parameters
      l_request_id := apps.fnd_request.submit_request(
        application => :v_application_short_name
       ,program     => :v_concurrent_program_name
       ,argument1   => :v_parameter1    -- extend as needed for additional parameters
      );

      COMMIT;

      fnd_file.put_line(fnd_file.log,
        'Successfully rescheduled. Request ID: ' || l_request_id);
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
        'Error rescheduling ' || :v_concurrent_program_name || ': ' || SQLERRM);
      ROLLBACK;
END;
