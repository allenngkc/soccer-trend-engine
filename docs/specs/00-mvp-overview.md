# Spec: MVP Overview — Soccer Trend Terminal
Status: Draft
Owner: PM/Spec Agent
Approver: Tech Lead (Human)

---

## 1) Goal
Deliver an MVP of a terminal-style web application that computes conditional trends for soccer matches (e.g., possession < 50, corners >= 5) and displays win rates + match lists.

---

## 2) Included in MVP
### League & Seasons
- EPL only
- 2–3 seasons (depending on provider reliability)

### Filtering metrics
- possession
- corners
- shots
- shotsOnTarget
- isHome

### Outputs
- sample size n
- wins / draws / losses
- winRate
- avgGoalsFor / avgGoalsAgainst
- match list

### UI
- terminal layout with:
  - query builder
  - results KPIs
  - match list
  - basic breakdowns by season + home/away

### Backend
- GET /teams
- GET /seasons
- POST /trends/run
- Strict validation via Zod

### Ingestion
- EPL matches and team stats
- Normalize stats
- Prisma upsert pipeline

---

## 3) Excluded (MVP)
- Odds
- Live data
- ML predictions
- Multi-league support
- User accounts + Stripe (post-MVP or week 6+)

---

## 4) Success criteria
A user can:
1. Select a team & seasons  
2. Add filters (1–3)  
3. Run query  
4. Get results in < 1 second  
5. See match list + basic breakdowns  

---

## 5) Data requirements
- All EPL matches (selected seasons)
- All team stats per match
- Normalized fields:
  - possession (float)
  - goalsFor/goalsAgainst
  - result (W/D/L)

---

## 6) API contracts

### GET /v1/teams?competition=EPL
→ `[{ teamId, name }]`

### GET /v1/seasons?competition=EPL
→ `[{ season }]`

### POST /v1/trends/run
Body:
- TrendDSL (see ARCHITECTURE.md)

Response:
- KPIs
- rates (btts, over2.5 — optional)
- match list
- quality indicators

---

## 7) UI contract
### Query builder
- Team selector
- Season selector
- Filter rows
- Run button

### Results
- KPI cards: n, W/D/L, winRate, avg GF/GA
- Table listing matches
- Simple breakdowns

---

## 8) Test plan
### Backend tests
- DSL validation  
- Aggregation logic correctness  
- Filtering combinations  

### Worker tests
- Ingestion idempotency  
- Data normalization  

### Frontend tests
- Query builder interactions  
- Result rendering  

---

## 9) Recommended PR breakdown
1. DB schema + Prisma setup  
2. Ingestion for one season  
3. `/teams` + `/seasons` endpoints  
4. `/trends/run` minimal implementation  
5. Query builder UI  
6. KPI + match list rendering  
7. Breakdowns  
8. Performance polish  

---

## 10) Open questions
- Provider data source?  
- xG included?  
- Seasons supported?  
