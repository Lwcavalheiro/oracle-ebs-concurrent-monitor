-- =============================================================================
-- Query: Scheduled Request Sets with Per-Program Parameters
-- Description: For Request Sets with active periodic scheduling, retrieves
--              the parameters of each individual program inside the set.
--              Uses FND_RUN_REQUESTS — the key table for Request Set introspection.
--
-- Important note: Individual concurrent programs store their parameters in
-- FND_CONCURRENT_REQUESTS.ARGUMENT_TEXT. Request Sets, however, store each
-- child program's parameters in FND_RUN_REQUESTS. The join is:
--   frr.set_application_id = r.argument1
--   frr.request_set_id     = r.argument2
--   frr.parent_request_id  = r.request_id
--
-- Demand: D-11502
-- Base for view: XXFND_CCR_DET_CONJUNTOS_V
-- Tables: FND_CONCURRENT_REQUESTS, FND_RUN_REQUESTS,
--         FND_CONCURRENT_PROGRAMS_TL, FND_USER, FND_RESPONSIBILITY_TL
-- =============================================================================

SELECT DISTINCT
       frr.request_set_id
      ,r.description                                         set_name
      ,u.user_name
      ,NVL(TO_CHAR(r.org_id), 'Null')                       org_id
      ,frt.responsibility_name                               responsibility
      ,DECODE(r.hold_flag, 'Y', 'Yes', 'N', 'No')           on_hold
      ,r.argument_text                                       set_parameters
      ,r.resubmit_interval                                   run_every
      ,r.resubmit_interval_unit_code                         period
      ,r.increment_dates
      ,pt1.user_concurrent_program_name                      program_in_set
      ,pb1.concurrent_program_id
      -- Concatenates arguments for each program inside the set (up to 10)
      ,DECODE(frr.argument1,  NULL, '', frr.argument1  || ',')
    ||DECODE(frr.argument2,  NULL, '', frr.argument2  || ',')
    ||DECODE(frr.argument3,  NULL, '', frr.argument3  || ',')
    ||DECODE(frr.argument4,  NULL, '', frr.argument4  || ',')
    ||DECODE(frr.argument5,  NULL, '', frr.argument5  || ',')
    ||DECODE(frr.argument6,  NULL, '', frr.argument6  || ',')
    ||DECODE(frr.argument7,  NULL, '', frr.argument7  || ',')
    ||DECODE(frr.argument8,  NULL, '', frr.argument8  || ',')
    ||DECODE(frr.argument9,  NULL, '', frr.argument9  || ',')
    ||DECODE(frr.argument10, NULL, '', frr.argument10 || ',') program_parameters
  FROM applsys.fnd_concurrent_programs_tl  pt
      ,applsys.fnd_concurrent_programs     pb
      ,applsys.fnd_user                    u
      ,applsys.fnd_user                    u2
      ,applsys.fnd_printer_styles_tl       s
      ,applsys.fnd_concurrent_requests     r
      ,applsys.fnd_responsibility_tl       frt
      ,applsys.fnd_run_requests            frr    -- child programs of the Request Set
      ,applsys.fnd_concurrent_programs_tl  pt1
      ,applsys.fnd_concurrent_programs     pb1
 WHERE pb.application_id          = r.program_application_id
   AND pb.concurrent_program_id   = r.concurrent_program_id
   AND pb.application_id          = pt.application_id
   AND r.responsibility_id        = frt.responsibility_id
   AND pb.concurrent_program_id   = pt.concurrent_program_id
   AND u.user_id                  = r.requested_by
   AND u2.user_id                 = r.last_updated_by
   AND s.printer_style_name(+)    = r.print_style
   AND pt.LANGUAGE                = USERENV('LANG')
   AND r.hold_flag                = 'N'
   AND frt.LANGUAGE               = USERENV('LANG')
   AND r.resubmit_interval        IS NOT NULL
   AND pt.user_concurrent_program_name = 'Report Set'  -- Request Sets only
   -- Key join: links the set-level request to its child programs
   AND frr.set_application_id     = r.argument1
   AND frr.request_set_id         = r.argument2
   AND frr.parent_request_id      = r.request_id
   AND pb1.application_id         = frr.application_id
   AND pb1.concurrent_program_id  = frr.concurrent_program_id
   AND pb1.concurrent_program_id  = pt1.concurrent_program_id
   AND pb1.application_id         = pt1.application_id
 ORDER BY set_name;
