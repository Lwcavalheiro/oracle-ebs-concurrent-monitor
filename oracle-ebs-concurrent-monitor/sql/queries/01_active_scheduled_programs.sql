-- =============================================================================
-- Query: Active Scheduled Concurrent Programs
-- Description: Returns all concurrent programs with active periodic scheduling.
--              Filters for pending requests (phase_code = 'P') not on hold,
--              with a future next-run date and a resubmit interval configured.
--              This is the backbone of view XXFND_CCR_CONTROLE_PRG_V and
--              Tab 1 of the XXFNDCTRLCCR Forms screen.
-- Demand: D-11502
-- Tables: FND_CONCURRENT_REQUESTS, FND_CONCURRENT_PROGRAMS_TL,
--         FND_CONCURRENT_PROGRAMS, FND_USER, FND_RESPONSIBILITY_TL,
--         FND_PRINTER_STYLES_TL
-- =============================================================================

SELECT DISTINCT
       r.request_id
      ,CASE
         -- Request Sets appear as the generic name "Report Set" in EBS.
         -- The CASE replaces it with the set's own description when available.
         WHEN pt.user_concurrent_program_name = 'Report Set' THEN
           DECODE(r.description,
                  NULL, pt.user_concurrent_program_name,
                  r.description || ' (' || pt.user_concurrent_program_name || ')')
         ELSE pt.user_concurrent_program_name
       END                                                   program_name
      ,u.user_name                                           requestor
      ,NVL(TO_CHAR(r.org_id), 'Null')                       org_id
      ,u.description                                         requestor_description
      ,u.email_address
      ,frt.responsibility_name                               responsibility
      ,r.request_date
      ,r.requested_start_date
      ,DECODE(r.hold_flag, 'Y', 'Yes', 'N', 'No')           on_hold
      ,r.argument_text                                       parameters
      ,NVL2(r.resubmit_interval,
            'Periodically',
            NVL2(r.release_class_id,
                 'On specific days',
                 'Once'))                                    schedule_type
      ,r.resubmit_interval                                   resubmit_every
      ,r.resubmit_interval_unit_code                         resubmit_time_period
      ,DECODE(r.resubmit_interval_type_code,
              'START', 'From the start of the prior run',
              'END',   'From the completion of the prior run') apply_option
      ,r.increment_dates
      ,TO_CHAR(r.requested_start_date, 'DD/MM/YYYY HH24:MI:SS') start_time
  FROM applsys.fnd_concurrent_programs_tl  pt
      ,applsys.fnd_concurrent_programs     pb
      ,applsys.fnd_user                    u
      ,applsys.fnd_user                    u2
      ,applsys.fnd_printer_styles_tl       s
      ,applsys.fnd_concurrent_requests     r
      ,applsys.fnd_responsibility_tl       frt
 WHERE pb.application_id          = r.program_application_id
   AND pb.concurrent_program_id   = r.concurrent_program_id
   AND pb.application_id          = pt.application_id
   AND r.responsibility_id        = frt.responsibility_id
   AND pb.concurrent_program_id   = pt.concurrent_program_id
   AND u.user_id                  = r.requested_by
   AND u2.user_id                 = r.last_updated_by
   AND s.printer_style_name(+)    = r.print_style
   AND r.phase_code               = 'P'             -- Pending: waiting for next run
   AND r.requested_start_date     > SYSDATE         -- Next run is in the future
   AND pt.LANGUAGE                = 'US'
   AND r.hold_flag                = 'N'             -- Not on hold
   AND frt.LANGUAGE               = 'US'
   AND r.resubmit_interval        IS NOT NULL       -- Has periodic scheduling
 ORDER BY program_name;
