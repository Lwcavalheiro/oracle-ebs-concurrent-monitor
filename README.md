# Oracle EBS R12 — Concurrent Program Scheduling Monitor (D-11502)

> **Context:** Customization developed for a **major Brazilian media company** on Oracle E-Business Suite R12, FND (Foundation / Sysadmin) module. The goal was to build an automated monitoring mechanism over scheduled Concurrent Programs and Request Sets — detecting lost schedules and alerting the team via email.

---

## The Problem

In large Oracle EBS environments, dozens (or hundreds) of Concurrent Programs run on periodic schedules — imports, accounting closures, email dispatches, bank remittances, integrations, and more.

The problem is simple but critical: **schedules can be lost silently.**

This happens for several reasons:
- An update patch that resets the environment
- A fatal execution error that cancels all future resubmissions
- An accidental user action placing a program "On Hold"
- A Concurrent Manager restart without rescheduling

When a critical process stops running, the team typically finds out **hours or days later**, when the side effects have already reached operations: a payment not sent, a billing email not dispatched, an integration stalled.

The company had no automated mechanism to detect this. The "solution" was manual, sporadic verification — entirely dependent on people.

---

## The Solution

Demand **D-11502** delivered a complete monitoring system composed of:

1. **Custom Oracle Forms screen** (`XXFNDCTRLCCR`) — registration and monitoring console
2. **Three custom tables** — storing monitored programs and request sets
3. **Three views** — consolidated queries of scheduled programs and their details
4. **PL/SQL Package** (`XXFND_MONITORA_CCR_PK`) — verification engine and email dispatcher
5. **Concurrent Program** (`ABRL - FND - Controle de Programação de Concorrentes`) — triggers the monitoring periodically
6. **FND Lookup** (`ABRL_FND_CONTROLA_CCR`) — email recipient configuration

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Oracle EBS — Concurrent Manager                             │
│                                                              │
│  FND_CONCURRENT_REQUESTS  (active scheduled requests)        │
│             │                                                │
│             ▼                                                │
│  XXFND_CCR_CONTROLE_PRG_V  ◄── Scheduling status view       │
│             │                                                │
│             ▼                                                │
│  XXFNDCTRLCCR.fmb  (Oracle Forms)                            │
│  ┌──────────────────────────────────────┐                    │
│  │  Tab 1: Browse Scheduled Programs    │                    │
│  │  Tab 2: Monitor / Reschedule         │                    │
│  └──────────────────────────────────────┘                    │
│             │  (user flags programs for monitoring)          │
│             ▼                                                │
│  XXFND_CONTROLE_CONCURRENTS  (individual programs table)     │
│  XXFND_CTRL_GRP_HEADERS/LINES  (request sets table)         │
│             │                                                │
│             ▼                                                │
│  Concurrent: ABRL - FND - Controle de Programação           │
│  (runs periodically, triggers the verification)             │
│             │                                                │
│             ▼                                                │
│  XXFND_MONITORA_CCR_PK.XXFND_ENVIA_EMAIL_P                  │
│  (checks schedules → sends email alert if missing)          │
│             │                                                │
│             ▼                                                │
│  Lookup ABRL_FND_CONTROLA_CCR  (email recipients)           │
└──────────────────────────────────────────────────────────────┘
```

---

## Database Objects

### Tables

**`XXFND_CONTROLE_CONCURRENTS`** — Stores individual Concurrent Programs under monitoring:

```sql
CREATE TABLE bolinf.xxfnd_controle_concurrents (
  ativo                   VARCHAR2(3),        -- 'Sim' = active monitoring
  concurrent_program_id   NUMBER,
  concurrent_program_name VARCHAR2(240),
  org_id                  NUMBER,
  user_name               VARCHAR2(100),      -- user who originally scheduled it
  resp_id                 NUMBER,
  responsabilidade        VARCHAR2(100),
  parametros              VARCHAR2(240),
  executar_a_cada         NUMBER,             -- numeric interval (e.g. 1)
  periodo                 VARCHAR2(30),       -- HOURS / DAYS / MONTHS / MINUTES
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_LOGIN       NUMBER
);
```

**`XXFND_CTRL_GRP_HEADERS`** — Header of monitored Request Sets (one row per set):

```sql
CREATE TABLE bolinf.xxfnd_ctrl_grp_headers (
  cod                     NUMBER,            -- PK
  ativo                   VARCHAR2(3),       -- 'S' = active
  concurrent_program_id   NUMBER,            -- Request Set ID
  concurrent_program_name VARCHAR2(240),
  org_id                  NUMBER,
  user_name               VARCHAR2(100),
  resp_id                 NUMBER,
  responsabilidade        VARCHAR2(100),
  executar_a_cada         NUMBER,
  periodo                 VARCHAR2(30),
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_LOGIN       NUMBER,
  CONSTRAINT xxfnd_ctrl_grp_he PRIMARY KEY (cod)
);
```

**`XXFND_CTRL_GRP_LINES`** — Lines of Request Sets — each individual program inside the set:

```sql
CREATE TABLE bolinf.xxfnd_ctrl_grp_lines (
  cod                     NUMBER,            -- FK to XXFND_CTRL_GRP_HEADERS
  ativo                   VARCHAR2(3),
  concurrent_program_id   NUMBER,
  concurrent_program_name VARCHAR2(240),
  org_id                  NUMBER,
  user_name               VARCHAR2(100),
  resp_id                 NUMBER,
  responsabilidade        VARCHAR2(100),
  parametros              VARCHAR2(240),     -- parameters for this program within the set
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_LOGIN       NUMBER,
  CONSTRAINT xxfnd_ctrl_grp_lines_fk
    FOREIGN KEY (cod)
    REFERENCES bolinf.xxfnd_ctrl_grp_headers (cod)
);
```

---

### Views

| View | Purpose |
|---|---|
| `XXFND_CCR_CONTROLE_PRG_V` | Real-time list of all actively scheduled programs. Feeds Tab 1 of the Forms screen |
| `XXFND_CCR_DET_CONJUNTOS_V` | Details the individual programs inside each scheduled Request Set |
| `XXFND_CONSULTA_DETALHES_V` | Displays parameters for programs registered inside a set |

---

### Core Query — Active Scheduled Concurrent Programs

The backbone of the solution. Identifies all programs with active periodic scheduling:

```sql
SELECT DISTINCT
       r.request_id
      ,CASE
         WHEN pt.user_concurrent_program_name = 'Report Set' THEN
           DECODE(r.description, NULL, pt.user_concurrent_program_name,
                  r.description || ' (' || pt.user_concurrent_program_name || ')')
         ELSE pt.user_concurrent_program_name
       END                                                   program_name
      ,u.user_name                                           requestor
      ,NVL(TO_CHAR(r.org_id), 'Null')                       org_id
      ,frt.responsibility_name                               responsibility
      ,DECODE(r.hold_flag, 'Y', 'Yes', 'N', 'No')           on_hold
      ,r.argument_text                                       parameters
      ,NVL2(r.resubmit_interval, 'Periodically',
            NVL2(r.release_class_id, 'On specific days', 'Once')) schedule_type
      ,r.resubmit_interval                                   resubmit_every
      ,r.resubmit_interval_unit_code                         resubmit_time_period
      ,DECODE(r.resubmit_interval_type_code,
              'START', 'From the start of the prior run',
              'END',   'From the completion of the prior run') apply_option
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
   AND r.phase_code               = 'P'              -- Pending: waiting for next run
   AND r.requested_start_date     > SYSDATE          -- Next run is in the future
   AND pt.LANGUAGE                = 'US'
   AND r.hold_flag                = 'N'              -- Not on hold
   AND frt.LANGUAGE               = 'US'
   AND r.resubmit_interval        IS NOT NULL        -- Has periodic scheduling
 ORDER BY program_name;
```

**Key filters explained:**
- `phase_code = 'P'` → only pending requests (waiting for the next scheduled run)
- `resubmit_interval IS NOT NULL` → only programs with periodic scheduling
- `hold_flag = 'N'` → excludes programs placed on hold
- The `CASE` on `program_name` handles Request Sets, which appear as the generic name "Report Set" in EBS but carry their own description

---

### Query — Request Sets with Per-Program Parameters

For Request Sets, it is necessary to retrieve parameters for **each program inside the set**. This requires joining `FND_RUN_REQUESTS`:

```sql
SELECT DISTINCT
       frr.request_set_id
      ,r.description                                         set_name
      ,u.user_name
      ,NVL(TO_CHAR(r.org_id), 'Null')                       org_id
      ,frt.responsibility_name                               responsibility
      ,r.resubmit_interval                                   run_every
      ,r.resubmit_interval_unit_code                         period
      ,pt1.user_concurrent_program_name                      program_in_set
      ,pb1.concurrent_program_id
      -- Concatenates parameters for each program inside the set (up to 10 arguments)
      ,DECODE(frr.argument1,  NULL, '', frr.argument1  || ',')
    ||DECODE(frr.argument2,  NULL, '', frr.argument2  || ',')
    ||DECODE(frr.argument3,  NULL, '', frr.argument3  || ',')
    ||DECODE(frr.argument4,  NULL, '', frr.argument4  || ',')
    ||DECODE(frr.argument5,  NULL, '', frr.argument5  || ',')
    ||DECODE(frr.argument6,  NULL, '', frr.argument6  || ',')
    ||DECODE(frr.argument7,  NULL, '', frr.argument7  || ',')
    ||DECODE(frr.argument8,  NULL, '', frr.argument8  || ',')
    ||DECODE(frr.argument9,  NULL, '', frr.argument9  || ',')
    ||DECODE(frr.argument10, NULL, '', frr.argument10 || ',') set_parameters
  FROM applsys.fnd_concurrent_requests     r
      ,applsys.fnd_run_requests            frr
      ,applsys.fnd_concurrent_programs_tl  pt1
      ,applsys.fnd_concurrent_programs     pb1
      -- ... (standard joins for pt, pb, u, frt)
 WHERE r.hold_flag                        = 'N'
   AND r.resubmit_interval               IS NOT NULL
   AND pt.user_concurrent_program_name   = 'Report Set'
   -- FND_RUN_REQUESTS join: argument1 = set_application_id, argument2 = request_set_id
   AND frr.set_application_id            = r.argument1
   AND frr.request_set_id               = r.argument2
   AND frr.parent_request_id            = r.request_id
   AND pb1.application_id               = frr.application_id
   AND pb1.concurrent_program_id        = frr.concurrent_program_id
 ORDER BY set_name;
```

---

### PL/SQL Package — `XXFND_MONITORA_CCR_PK`

The engine of the solution. The procedure `XXFND_ENVIA_EMAIL_P` is invoked by the Concurrent Program and performs the following steps:

1. Reads all active records from `XXFND_CONTROLE_CONCURRENTS` (individual programs)
2. For each, checks whether a matching active entry exists in `FND_CONCURRENT_REQUESTS` with `resubmit_interval IS NOT NULL`
3. Repeats the same check for Request Sets via `XXFND_CTRL_GRP_HEADERS`
4. For any program found without an active schedule, composes an alert email with full details
5. Sends the alert to recipients configured in Lookup `ABRL_FND_CONTROLA_CCR`

See full source: [`sql/packages/XXFND_MONITORA_CCR_PKS.pls`](sql/packages/XXFND_MONITORA_CCR_PKS.pls) and [`sql/packages/XXFND_MONITORA_CCR_PKB.pls`](sql/packages/XXFND_MONITORA_CCR_PKB.pls)

---

### Concurrent Program

| Attribute | Value |
|---|---|
| Name | `ABRL - FND - Controle de Programação de Concorrentes` |
| Executable Code | `ABRL_FND_CTRL_PROG_CCR` |
| Execution File | `BOLINF.XXFND_MONITORA_CCR_PK.XXFND_ENVIA_EMAIL_P` |
| Request Group | `XXFND_SYSADMIN_QUERY_ONLY` |
| Type | PL/SQL Stored Procedure |

---

### FND Lookup — Email Recipient Configuration

The Lookup `ABRL_FND_CONTROLA_CCR` allows the functional team to manage alert recipients without any code change — directly through the EBS Sysadmin Lookups screen:

| Field | Usage |
|---|---|
| Lookup Type | `ABRL_FND_CONTROLA_CCR` |
| Code | Sequential number |
| Meaning | `EMAIL_DE` (sender) or `EMAIL_PARA` (recipient) |
| Description | Email address |
| Effective Date | Registration date |

---

### Oracle Forms Screen — `XXFNDCTRLCCR`

The Forms screen was built with **two tabs**:

**Tab 1 — Browse Scheduled Programs**
- Displays in real time all programs with active periodic scheduling (via `XXFND_CCR_CONTROLE_PRG_V`)
- **Monitor flag**: when checked, the program is enrolled in the monitoring control tables
- **Set Details button**: available only for Request Sets — opens a detail window showing each stage program and its parameters

**Tab 2 — Monitor & Reschedule**
- Lists all programs registered in the control tables
- Shows current **Status**: `Scheduled` or `Not Scheduled`
- **Refresh button**: reloads statuses
- **Reschedule button**: enabled only when status = `Not Scheduled` — triggers rescheduling via Oracle API
- **Parameters button**: opens a parameter detail window for individual programs

**Forms dependent-field cleanup triggers:**

```sql
-- Clears CONCURRENT_PROGRAM_ID when the program name item is validated
BEGIN
  APP_FIELD.CLEAR_DEPENDENT_FIELDS(
    'XXCCR.CONCURRENT_PROGRAM_NAME',
    'XXCCR.CONCURRENT_PROGRAM_ID'
  );
END;

-- Clears RESP_ID when the responsibility item is validated
BEGIN
  APP_FIELD.CLEAR_DEPENDENT_FIELDS(
    'XXCCR.RESPONSABILIDADE',
    'XXCCR.RESP_ID'
  );
END;
```

---

### Reschedule API — Individual Concurrent Program

The **Reschedule** button on Tab 2 uses the standard Oracle `FND_REQUEST` API:

```sql
DECLARE
  l_request_id         NUMBER;
  l_set_repeat_options BOOLEAN;
BEGIN
  FND_GLOBAL.APPS_INITIALIZE(
    user_id      => :v_user_id,
    resp_id      => :v_resp_id,
    resp_appl_id => :v_resp_appl_id
  );

  l_set_repeat_options := apps.fnd_request.set_repeat_options(
    repeat_time     => NULL,
    repeat_interval => :v_run_every,    -- e.g. 1
    repeat_unit     => :v_period,       -- HOURS / DAYS / MONTHS / MINUTES
    repeat_type     => 'START',         -- counted from start of previous run
    repeat_end_time => NULL,
    increment_dates => NULL
  );

  IF l_set_repeat_options THEN
    l_request_id := apps.fnd_request.submit_request(
      application => :v_application_short_name,
      program     => :v_concurrent_program_name,
      argument1   => :v_parameter1
    );
    COMMIT;
  END IF;
END;
```

For **Request Sets**, the same logic uses `FND_SUBMIT`, iterating over each program in the set:

```sql
l_success    := apps.fnd_submit.set_request_set(:v_app_short_name, :v_request_set_name);
-- submit each inner program via fnd_submit.submit_program(...)
l_request_id := apps.fnd_submit.submit_set(NULL, FALSE);
COMMIT;
```

See full implementation: [`sql/api/01_reschedule_concurrent.sql`](sql/api/01_reschedule_concurrent.sql) and [`sql/api/02_reschedule_request_set.sql`](sql/api/02_reschedule_request_set.sql)

---

## Patch Delivery Objects

Patch `1200001527` included the following files:

| Object Type | File |
|---|---|
| Menu | `MNU_XXFND_SYSAD_QUERY_ONLY.ldt` |
| Lookup | `LKP_ABRL_FND_CONTROLA_CCR.ldt` |
| Form | `XXFNDCTRLCCR.fmb` |
| Package Spec | `XXFND_MONITORA_CCR_PKS.pls` |
| Package Body | `XXFND_MONITORA_CCR_PKB.pls` |
| Concurrent Program | `CCR_ABRL_FND_CTRL_PROG_CCR.ldt` |
| Table | `XXFND_CONTROLE_CONCURRENTS.tab` |
| Table | `XXFND_CTRL_GRP_HEADERS.tab` |
| Table | `XXFND_CTRL_GRP_LINES.tab` |
| View | `XXFND_CCR_CONTROLE_PRG_V.vw` |
| Grants | `*.grt` for all tables and views |
| Request Group | `RQG_SYSADMIN_QUERY_ONLY.ldt` |

---

## Key Takeaways

**1. `FND_RUN_REQUESTS` is the key to introspecting Request Sets**
While individual concurrent programs store their parameters directly in `FND_CONCURRENT_REQUESTS.argument_text`, Request Sets store the parameters of each child program in `FND_RUN_REQUESTS`. This is a less-documented table, but essential for anyone who needs to inspect or replicate a scheduled set.

**2. Header/Lines model for Request Sets**
Modeling the control table as header + lines (rather than a flat table) correctly represents the hierarchy of Request Sets, where one set contains multiple programs with independent parameters.

**3. FND Lookup for email configuration**
Using a standard FND Lookup for alert recipients means the functional team can update the distribution list without involving development — just the Sysadmin Lookups screen.

**4. The Reschedule button as a safety net**
Beyond the email alert, the reschedule button embedded in the Forms screen means the operator does not need to navigate the Concurrent Manager to fix the issue — reducing response time and the risk of human error.

---

## Repository Structure

```
oracle-ebs-concurrent-monitor/
│
├── README.md
│
├── sql/
│   ├── tables/
│   │   ├── 01_XXFND_CONTROLE_CONCURRENTS.sql
│   │   └── 02_XXFND_CTRL_GRP_HEADERS_LINES.sql
│   │
│   ├── queries/
│   │   ├── 01_active_scheduled_programs.sql
│   │   ├── 02_request_sets_with_parameters.sql
│   │   └── 03_control_table_report.sql
│   │
│   ├── api/
│   │   ├── 01_reschedule_concurrent.sql
│   │   └── 02_reschedule_request_set.sql
│   │
│   └── packages/
│       ├── XXFND_MONITORA_CCR_PKS.pls
│       └── XXFND_MONITORA_CCR_PKB.pls
│
└── docs/
    └── architecture-overview.md
```

---

*Demand: D-11502 | Module: FND/Sysadmin | Patch: 1200001527 | Oracle EBS R12*
