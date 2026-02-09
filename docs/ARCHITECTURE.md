# **`docs/ARCHITECTURE.md`**
# Soccer Trend Terminal — Architecture

## 0) Purpose
This document defines the technical architecture for the Soccer Trend Terminal MVP. It is the source of truth for:
- Repo structure
- Data model
- APIs and contracts
- Query DSL
- Engineering constraints and boundaries

The goal is a terminal-style web app where users can query historical soccer match conditions (e.g., possession < 50, corners >= 5) and compute outcomes (win rate, W/D/L counts, etc.).

---

## 1) Stack (MVP)
### Frontend
- Next.js (TypeScript)
- Tailwind CSS (terminal-like UI)
- TanStack Query for data fetching and caching

### Backend
- Node.js + Express (TypeScript)
- Zod for request validation
- Prisma for DB access (Postgres)

### Storage
- Postgres (primary database)
- Redis (optional for caching & rate limiting in later weeks)
- S3 (optional for raw provider snapshots & exports in later weeks)

---

## 2) Repository structure (monorepo)
Use a simple monorepo to keep boundaries clear:

- /apps
- /web # Next.js terminal UI
- /api # Express REST API
- /packagesdependencies)
- /db # Prisma client wrapper, DB utilities
- /docs
- ARCHITECTURE.md
- AGENTS.md
- TASKS.md
- /docs/specs
 00-mvp-overview.md

 
### Ownership boundaries
- apps/web → UI  
- apps/api → API  
- apps/worker → ingestion  
- packages/shared → types only  
- packages/db → Prisma client  

---

## 3) Data model (MVP)
Core tables:

### Team
- id (pk)
- name
- country (optional)
- league (optional)
- createdAt, updatedAt

### Match
- id (pk)
- competition (e.g. "EPL")
- season (e.g. "2024-2025")
- matchDate (timestamp)
- homeTeamId
- awayTeamId
- homeGoals
- awayGoals
- status ("scheduled" | "finished")
- createdAt, updatedAt

### TeamMatchStats
- id (pk) OR (matchId, teamId unique)
- matchId
- teamId
- isHome
- goalsFor
- goalsAgainst
- result ("W" | "D" | "L")
- possession
- corners
- shots
- shotsOnTarget
- xg (optional)
- xga (optional)
- fouls (optional)
- yellow (optional)
- red (optional)
- createdAt, updatedAt

### Index recommendations
- TeamMatchStats(teamId, matchId)
- TeamMatchStats(teamId)
- Match(competition, season, matchDate)

---

## 4) Query DSL
A JSON format used by frontend → backend for trend queries.

### Example
```json
{
  "teamId": 33,
  "competition": "EPL",
  "seasons": ["2022-2023", "2023-2024"],
  "filters": [
    { "field": "possession", "op": "<", "value": 50 },
    { "field": "corners", "op": ">=", "value": 5 },
    { "field": "isHome", "op": "=", "value": true }
  ],
  "outcomes": ["win_rate", "btts_rate", "over_2_5_rate"]
}

```
### Allowed filter fields

- isHome
- possession
- corners
- shots
- shotsOnTarget
- xg (optional)
- fouls/yellow/red (optional)

#### Allowed ops

- "="
- "!="
- "<"
- "<="
- ">"
- ">="
- "between"
- Normalization rules (for caching)
- Sort filters alphabetically
- Sort seasons array
- Normalize boolean + numeric types
- Lowercase competition


## 5) REST API (MVP)

Base path: /v1

### GET /teams?competition=EPL

Response:

```json
[{ "teamId": 1, "name": "Manchester United" }]
```

### GET /seasons?competition=EPL

Response:
```json
[{ "season": "2023-2024" }]
```

### POST /v1/trends/run

Body: TrendDSL

```json
{
  "meta": {...},
  "kpis": {
    "n": 63,
    "wins": 24,
    "draws": 18,
    "losses": 21,
    "winRate": 0.381,
    "avgGoalsFor": 1.27,
    "avgGoalsAgainst": 1.13
  },
  "rates": {
    "bttsRate": 0.54,
    "over2_5Rate": 0.49
  },
  "matches": [...],
  "quality": {
    "sampleSizeTier": "medium",
    "warnings": []
  }
}

```

Error format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request",
    "details": {}
  }
}
```

## 6) Query Engine Architecture


- Validate TrendDSL with Zod
- Translate DSL → Prisma where filters
- Query TeamMatchStats with Match join
- Aggregate:
- n
- wins/draws/losses
- winRate
- averages
- Return match list (capped if large)
- Performance target: p95 < 500ms

## 7) Ingestion Pipeline

Runs under apps/worker:
- Fetch matches + stats from provider
- Normalize fields (procession 0..100)
- Compute goalsFor/goalsAgainst an result
- Prisma upserts
- Idempotent and safe to rerun

## 8) Security
- Strict allowlists for TrendDSL
- Zod validation
- No raw SQL
- Rate Limiting (Later)

