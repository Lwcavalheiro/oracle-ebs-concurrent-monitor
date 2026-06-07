# Architecture Overview — D-11502 Concurrent Monitor

## Component Map

```
┌───────────────────────────────────────────────────────────────────┐
│  ORACLE EBS R12 — FND/Sysadmin                                    │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  FND_CONCURRENT_REQUESTS          (Oracle standard table)   │  │
│  │  • phase_code = 'P'               (pending)                 │  │
│  │  • resubmit_interval IS NOT NULL  (has periodic schedule)   │  │
│  │  • hold_flag = 'N'                (not on hold)             │  │
│  └───────────────────┬─────────────────────────────────────────┘  │
│                      │                                            │
│                      ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  VIEWS (custom)                                             │  │
│  │  • XXFND_CCR_CONTROLE_PRG_V   — active scheduled programs  │  │
│  │  • XXFND_CCR_DET_CONJUNTOS_V  — Request Set program detail │  │
│  │  • XXFND_CONSULTA_DETALHES_V  — registered set parameters  │  │
│  └───────────────────┬─────────────────────────────────────────┘  │
│                      │                                            │
│                      ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  XXFNDCTRLCCR.fmb  (Oracle Forms — custom screen)          │  │
│  │                                                             │  │
│  │  Tab 1 — Browse Scheduled Programs                         │  │
│  │    [x] Monitor flag ──────────────────────────────────┐    │  │
│  │    [Set Details] button (Request Sets only)           │    │  │
│  │                                                       │    │  │
│  │  Tab 2 — Monitor & Reschedule                         │    │  │
│  │    Status: Scheduled / Not Scheduled  ◄───────────────┘    │  │
│  │    [Refresh]     [Reschedule]     [Parameters]             │  │
│  └───────┬──────────────────┬──────────────────────────────────┘  │
│          │ register         │ reschedule trigger                  │
│          ▼                  ▼                                      │
│  ┌──────────────────┐  ┌──────────────────────────────────────┐   │
│  │ CONTROL TABLES   │  │  RESCHEDULE API                      │   │
│  │                  │  │                                      │   │
│  │ XXFND_CONTROLE_  │  │  Individual → FND_REQUEST            │   │
│  │ CONCURRENTS      │  │    .set_repeat_options()             │   │
│  │                  │  │    .submit_request()                 │   │
│  │ XXFND_CTRL_GRP_  │  │                                      │   │
│  │ HEADERS          │  │  Request Set → FND_SUBMIT            │   │
│  │                  │  │    .set_request_set()                │   │
│  │ XXFND_CTRL_GRP_  │  │    .submit_program() (per stage)     │   │
│  │ LINES            │  │    .submit_set()                     │   │
│  └──────────────────┘  └──────────────────────────────────────┘   │
│          │                                                        │
│          ▼                                                        │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  Concurrent Program: ABRL_FND_CTRL_PROG_CCR                 │  │
│  │  (runs periodically — e.g. every 1 hour)                    │  │
│  │                                                             │  │
│  │  calls ──► XXFND_MONITORA_CCR_PK.XXFND_ENVIA_EMAIL_P       │  │
│  └───────────────────┬─────────────────────────────────────────┘  │
│                      │                                            │
│                      ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  MONITORING ENGINE (PL/SQL Package)                         │  │
│  │                                                             │  │
│  │  1. Read XXFND_CONTROLE_CONCURRENTS (active = 'Sim')        │  │
│  │  2. For each → check FND_CONCURRENT_REQUESTS                │  │
│  │  3. Read XXFND_CTRL_GRP_HEADERS (active = 'S')              │  │
│  │  4. For each → check FND_CONCURRENT_REQUESTS                │  │
│  │  5. If unscheduled found → compose + send alert email       │  │
│  └───────────────────┬─────────────────────────────────────────┘  │
│                      │                                            │
│                      ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  FND Lookup: ABRL_FND_CONTROLA_CCR                          │  │
│  │  • EMAIL_DE  → sender address                               │  │
│  │  • EMAIL_PARA → recipient address(es)                       │  │
│  │  (managed by functional team — no code change needed)       │  │
│  └─────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

| Step | Source | Action | Destination |
|------|--------|--------|-------------|
| 1 | Concurrent Manager | Triggers monitoring run | `XXFND_MONITORA_CCR_PK` |
| 2 | `XXFND_CONTROLE_CONCURRENTS` | Read active programs to check | PL/SQL cursor |
| 3 | `FND_CONCURRENT_REQUESTS` | Verify if each is still scheduled | Boolean result |
| 4 | `XXFND_CTRL_GRP_HEADERS/LINES` | Read active Request Sets to check | PL/SQL cursor |
| 5 | `FND_CONCURRENT_REQUESTS` | Verify if each set is still scheduled | Boolean result |
| 6 | `ABRL_FND_CONTROLA_CCR` (Lookup) | Read email recipients | Email dispatcher |
| 7 | Email utility | Send alert with unscheduled program list | Operations team |

## Key Oracle EBS Tables Used

| Table | Owner | Purpose |
|---|---|---|
| `FND_CONCURRENT_REQUESTS` | APPLSYS | All concurrent program submissions and schedules |
| `FND_RUN_REQUESTS` | APPLSYS | Programs and parameters inside a Request Set |
| `FND_CONCURRENT_PROGRAMS` | APPLSYS | Program definitions |
| `FND_CONCURRENT_PROGRAMS_TL` | APPLSYS | Program translated names |
| `FND_USER` | APPLSYS | EBS users |
| `FND_RESPONSIBILITY_TL` | APPLSYS | Responsibility names |
| `FND_LOOKUP_VALUES` | APPLSYS | Lookup values (email config) |
| `XXFND_CONTROLE_CONCURRENTS` | BOLINF | Custom: individual programs control |
| `XXFND_CTRL_GRP_HEADERS` | BOLINF | Custom: Request Sets control (header) |
| `XXFND_CTRL_GRP_LINES` | BOLINF | Custom: Request Sets control (lines) |
