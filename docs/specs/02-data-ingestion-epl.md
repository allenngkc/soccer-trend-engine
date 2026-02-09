# Spec: Data Ingestion Pipeline for EPL Matches (PR #2)

**Status:** Draft
**Owner:** PM/Spec Agent
**Approver:** Tech Lead (Human)
**Related:** MVP Overview (00-mvp-overview.md), ARCHITECTURE.md Section 7, PR #1 (Database Schema)

---

## 1) User Story

**As a** developer working on the Soccer Trend Terminal,
**I want** an automated ingestion pipeline that fetches EPL match data from a reliable provider and populates our database,
**So that** users can query historical match statistics for trend analysis.

---

## 2) Acceptance Criteria

### Must Have
1. ✅ Worker application structure in `apps/worker/` with TypeScript
2. ✅ Integration with a reliable EPL data provider (API identified and configured)
3. ✅ Fetch and store 2-3 seasons of EPL matches (2022-2023, 2023-2024, 2024-2025)
4. ✅ Upsert Teams (create if new, skip if exists)
5. ✅ Upsert Matches with basic info (competition, season, date, teams, score, status)
6. ✅ Upsert TeamMatchStats with normalized statistics for both home and away teams
7. ✅ Idempotent ingestion (safe to rerun without duplicates or data corruption)
8. ✅ Data normalization rules implemented:
   - Possession normalized to 0-100 float
   - Result (W/D/L) computed from goalsFor/goalsAgainst
   - All required field mappings from provider format to our schema
9. ✅ Error handling for missing/malformed data
10. ✅ Basic logging (info, warn, error levels)
11. ✅ CLI command to run ingestion manually
12. ✅ README.md with setup and usage instructions

### Should Have
13. ✅ Data quality checks (e.g., possession sum ≈ 100%, valid score ranges)
14. ✅ Progress indicators during ingestion
15. ✅ Summary report after ingestion (teams added, matches processed, errors encountered)

### Won't Have (Out of Scope)
- Automated scheduling (cron jobs, task queues) - manual execution only for MVP
- Real-time/live match data
- Multiple leagues (EPL only for MVP)
- Odds data
- Player-level statistics
- Historical data beyond 3 seasons
- Retry logic with exponential backoff (simple error logging only)
- Data validation beyond basic checks

---

## 3) Data Source Requirements

### 3.1) Provider Selection

**Recommended Provider:** **API-Football (RapidAPI)**
- **URL:** https://rapidapi.com/api-sports/api/api-football
- **Coverage:** Comprehensive EPL data with match statistics
- **Free Tier:** 100 requests/day (sufficient for initial ingestion if batched properly)
- **Paid Tier:** $10-30/month for higher limits if needed
- **Data Quality:** High (widely used, well-maintained)
- **Documentation:** Excellent with TypeScript examples

**Alternative Providers (if API-Football unavailable):**
1. **Football-Data.org** - Free tier available, good EPL coverage
2. **TheSportsDB** - Free for non-commercial use, decent coverage
3. **OpenLigaDB** - Free, but limited EPL coverage

**Decision Point:** Tech Lead must approve provider choice and provide API key.

### 3.2) Required API Endpoints

Using API-Football as reference:

1. **GET /teams** - Fetch all EPL teams for a season
   - Params: `league=39` (EPL), `season=2023`
   - Returns: Team ID, name, country

2. **GET /fixtures** - Fetch all matches for a season
   - Params: `league=39`, `season=2023`
   - Returns: Match ID, date, teams, score, status

3. **GET /fixtures/statistics** - Fetch detailed match statistics
   - Params: `fixture={matchId}`
   - Returns: Possession, shots, corners, fouls, cards, xG (if available)

### 3.3) Rate Limiting Considerations

- Free tier: 100 requests/day
- Strategy: Batch requests, cache responses, run ingestion during off-peak hours
- For 3 seasons × ~380 matches = ~1,140 matches
- With statistics endpoint: ~1,140 additional requests
- Total: ~2,280 requests (requires ~23 days on free tier, or paid plan)
- **Recommendation:** Use paid tier ($10/month) for initial ingestion, then minimal updates

---

## 4) Ingestion Architecture

### 4.1) Package Structure
```
apps/worker/
├── src/
│   ├── index.ts              # CLI entry point
│   ├── ingestion/
│   │   ├── ingest.ts         # Main orchestration logic
│   │   ├── fetchTeams.ts     # Fetch and upsert teams
│   │   ├── fetchMatches.ts   # Fetch and upsert matches
│   │   ├── fetchStats.ts     # Fetch and upsert match stats
│   │   └── normalize.ts      # Data normalization utilities
│   ├── providers/
│   │   ├── apiFootball.ts    # API-Football client
│   │   └── types.ts          # Provider response types
│   └── utils/
│       ├── logger.ts         # Logging utility
│       └── validation.ts     # Data quality checks
├── package.json
├── tsconfig.json
└── README.md
```

### 4.2) Execution Flow

```
1. CLI invoked: npm run ingest -- --season 2023-2024
2. Load environment variables (API key, DATABASE_URL)
3. Initialize Prisma client
4. For each season:
   a. Fetch teams → Upsert to Team table
   b. Fetch matches → Upsert to Match table
   c. For each match:
      - Fetch statistics
      - Normalize data
      - Compute result (W/D/L) for both teams
      - Upsert to TeamMatchStats (2 rows per match)
5. Log summary (teams added, matches processed, errors)
6. Close connections
```

### 4.3) CLI Interface

```bash
# Ingest all configured seasons
npm run ingest

# Ingest specific season
npm run ingest -- --season 2023-2024

# Dry run (fetch but don't write to DB)
npm run ingest -- --dry-run

# Verbose logging
npm run ingest -- --verbose
```

### 4.4) Scheduling (Out of Scope for MVP)

- Manual execution only for MVP
- Future: Add cron job or task queue (Bull, Agenda) for daily updates
- Future: Incremental updates (fetch only recent matches)

---

## 5) Data Normalization Rules

### 5.1) Team Normalization

**Provider → Our Schema:**
```typescript
{
  id: provider.team.id,           // Use provider's team ID
  name: provider.team.name,       // e.g., "Manchester United"
  country: "England",             // Hardcoded for EPL
  league: "EPL",                  // Hardcoded for EPL
}
```

**Rules:**
- Use provider's team ID as our primary key (or map if needed)
- Normalize team names (trim whitespace, consistent casing)
- Set country = "England" and league = "EPL" for all EPL teams

### 5.2) Match Normalization

**Provider → Our Schema:**
```typescript
{
  competition: "EPL",                          // Hardcoded
  season: "2023-2024",                         // From CLI arg or config
  matchDate: new Date(provider.fixture.date),  // ISO 8601 → DateTime
  homeTeamId: provider.teams.home.id,
  awayTeamId: provider.teams.away.id,
  homeGoals: provider.goals.home,              // null if not finished
  awayGoals: provider.goals.away,              // null if not finished
  status: provider.fixture.status.short === "FT" ? "finished" : "scheduled",
}
```

**Rules:**
- Convert provider status codes to our enum ("scheduled" | "finished")
- Handle null scores for scheduled matches
- Parse ISO 8601 dates to JavaScript Date objects

### 5.3) TeamMatchStats Normalization

**Provider → Our Schema (per team):**
```typescript
// For home team
{
  matchId: match.id,
  teamId: homeTeamId,
  isHome: true,
  goalsFor: homeGoals,
  goalsAgainst: awayGoals,
  result: computeResult(homeGoals, awayGoals),  // "W" | "D" | "L"
  possession: normalizePercentage(provider.statistics.possession),  // 0-100
  corners: provider.statistics.corner_kicks,
  shots: provider.statistics.total_shots,
  shotsOnTarget: provider.statistics.shots_on_goal,
  xg: provider.statistics.expected_goals ?? null,  // Optional
  xga: provider.statistics.expected_goals_against ?? null,  // Optional
  fouls: provider.statistics.fouls ?? null,
  yellow: provider.statistics.yellow_cards ?? null,
  red: provider.statistics.red_cards ?? null,
}

// Repeat for away team with isHome: false
```

**Normalization Functions:**

```typescript
// Compute result from goals
function computeResult(goalsFor: number, goalsAgainst: number): "W" | "D" | "L" {
  if (goalsFor > goalsAgainst) return "W";
  if (goalsFor < goalsAgainst) return "L";
  return "D";
}

// Normalize possession (handle "45%", 45, "45.5%" formats)
function normalizePercentage(value: string | number | null): number | null {
  if (value === null || value === undefined) return null;
  const num = typeof value === "string" ? parseFloat(value.replace("%", "")) : value;
  return isNaN(num) ? null : num;
}

// Validate possession sum (should be ~100%)
function validatePossession(home: number | null, away: number | null): boolean {
  if (home === null || away === null) return true; // Skip if missing
  const sum = home + away;
  return sum >= 98 && sum <= 102; // Allow 2% tolerance
}
```

**Rules:**
- Possession: Convert percentage strings to floats (0-100 range)
- Result: Always compute from goalsFor/goalsAgainst (don't trust provider's result field)
- Optional fields: Set to null if missing from provider
- Validation: Log warning if possession sum ≠ 100% (±2% tolerance)

---

## 6) Prisma Upsert Strategy

### 6.1) Idempotency Requirements

- **Teams:** Upsert by provider team ID (create if new, update name if changed)
- **Matches:** Upsert by unique key (competition, season, homeTeamId, awayTeamId, matchDate)
- **TeamMatchStats:** Upsert by unique key (matchId, teamId)

### 6.2) Upsert Implementation

**Team Upsert:**
```typescript
await prisma.team.upsert({
  where: { id: providerTeamId },
  update: { name: teamName, updatedAt: new Date() },
  create: {
    id: providerTeamId,
    name: teamName,
    country: "England",
    league: "EPL",
  },
});
```

**Match Upsert:**
```typescript
// First, find or create match by unique fields
const match = await prisma.match.upsert({
  where: {
    // Note: Prisma requires a unique constraint for upsert
    // May need to use findFirst + create/update pattern
    id: providerMatchId, // If using provider's match ID
  },
  update: {
    homeGoals,
    awayGoals,
    status,
    updatedAt: new Date(),
  },
  create: {
    competition: "EPL",
    season,
    matchDate,
    homeTeamId,
    awayTeamId,
    homeGoals,
    awayGoals,
    status,
  },
});
```

**TeamMatchStats Upsert:**
```typescript
await prisma.teamMatchStats.upsert({
  where: {
    matchId_teamId: { matchId: match.id, teamId },
  },
  update: {
    goalsFor,
    goalsAgainst,
    result,
    possession,
    corners,
    shots,
    shotsOnTarget,
    xg,
    xga,
    fouls,
    yellow,
    red,
    updatedAt: new Date(),
  },
  create: {
    matchId: match.id,
    teamId,
    isHome,
    goalsFor,
    goalsAgainst,
    result,
    possession,
    corners,
    shots,
    shotsOnTarget,
    xg,
    xga,
    fouls,
    yellow,
    red,
  },
});
```

### 6.3) Transaction Strategy

- Use Prisma transactions for related operations (match + stats)
- Batch upserts where possible (e.g., all teams in one transaction)
- Rollback on critical errors (e.g., foreign key violations)

**Example:**
```typescript
await prisma.$transaction(async (tx) => {
  // Upsert match
  const match = await tx.match.upsert({ ... });

  // Upsert home team stats
  await tx.teamMatchStats.upsert({ ... });

  // Upsert away team stats
  await tx.teamMatchStats.upsert({ ... });
});
```

---

## 7) Error Handling & Data Quality

### 7.1) Error Categories

1. **Network Errors:** API unavailable, timeout, rate limit exceeded
2. **Data Errors:** Missing required fields, invalid formats, constraint violations
3. **Business Logic Errors:** Invalid possession sum, negative stats, same team playing itself

### 7.2) Error Handling Strategy

**Network Errors:**
- Log error with context (endpoint, params)
- Skip current item, continue with next
- Report in summary (e.g., "5 matches failed to fetch")

**Data Errors:**
- Log warning with details (match ID, field, value)
- Use fallback values where safe (e.g., null for optional fields)
- Skip record if critical fields missing (e.g., no team IDs)

**Business Logic Errors:**
- Log warning (e.g., "Possession sum = 105% for match X")
- Store data anyway (don't block ingestion)
- Flag for manual review in summary

### 7.3) Data Quality Checks

**Pre-Insert Validation:**
```typescript
function validateMatchStats(stats: TeamMatchStats): ValidationResult {
  const errors: string[] = [];

  // Check possession range
  if (stats.possession !== null && (stats.possession < 0 || stats.possession > 100)) {
    errors.push(`Invalid possession: ${stats.possession}`);
  }

  // Check non-negative stats
  if (stats.corners !== null && stats.corners < 0) {
    errors.push(`Negative corners: ${stats.corners}`);
  }

  // Check goals consistency
  if (stats.goalsFor < 0 || stats.goalsAgainst < 0) {
    errors.push(`Negative goals: ${stats.goalsFor}/${stats.goalsAgainst}`);
  }

  return { valid: errors.length === 0, errors };
}
```

**Post-Insert Checks:**
- Count teams, matches, stats records
- Verify no orphaned records (stats without matches)
- Check for duplicate TeamMatchStats (should be prevented by unique constraint)

### 7.4) Logging

**Log Levels:**
- **INFO:** Progress updates (e.g., "Fetched 380 matches for 2023-2024")
- **WARN:** Non-critical issues (e.g., "Missing xG data for match 12345")
- **ERROR:** Critical failures (e.g., "Failed to fetch teams: API key invalid")

**Log Format:**
```
[2024-01-15 10:30:45] INFO: Starting ingestion for season 2023-2024
[2024-01-15 10:31:02] INFO: Fetched 20 teams
[2024-01-15 10:32:15] WARN: Missing possession data for match 54321
[2024-01-15 10:35:30] ERROR: Failed to fetch stats for match 67890: Rate limit exceeded
[2024-01-15 10:40:00] INFO: Ingestion complete. Summary: 20 teams, 380 matches, 760 stats, 5 errors
```

---

## 8) Environment Variables

Required in `.env`:
```bash
# Database connection (from PR #1)
DATABASE_URL="postgresql://user:password@localhost:5432/soccer_trends?schema=public"

# API-Football credentials
API_FOOTBALL_KEY="your_rapidapi_key_here"
API_FOOTBALL_HOST="api-football-v1.p.rapidapi.com"

# Optional: Ingestion config
SEASONS="2022-2023,2023-2024,2024-2025"  # Comma-separated
EPL_LEAGUE_ID="39"  # API-Football league ID for EPL
```

**Security:**
- Never commit `.env` to version control
- Provide `.env.example` with placeholder values
- Document how to obtain API key in README

---

## 9) Dependencies

### New Dependencies Required

```json
{
  "dependencies": {
    "@repo/db": "workspace:*",           // Prisma client from packages/db
    "axios": "^1.6.0",                   // HTTP client for API calls
    "dotenv": "^16.3.0",                 // Environment variable loading
    "commander": "^11.1.0"               // CLI argument parsing
  },
  "devDependencies": {
    "@types/node": "^20.10.0",
    "typescript": "^5.3.0",
    "tsx": "^4.7.0"                      // TypeScript execution for dev
  }
}
```

**Justification:**
- **axios:** Industry-standard HTTP client, better error handling than fetch
- **dotenv:** Standard for environment variable management
- **commander:** Robust CLI framework with TypeScript support
- **tsx:** Fast TypeScript execution for development (alternative: ts-node)

**Alternatives Considered:**
- **fetch (native):** Less ergonomic error handling, no request/response interceptors
- **got/ky:** Good alternatives to axios, but axios has larger ecosystem
- **yargs:** Alternative to commander, but commander is simpler for our use case

---

## 10) Verification Steps

### 10.1) Setup Verification
```bash
cd apps/worker
npm install
npm run build
```
**Expected:** No TypeScript errors, build succeeds.

### 10.2) Dry Run Test
```bash
npm run ingest -- --season 2023-2024 --dry-run
```
**Expected:**
- Logs show API calls being made
- No database writes
- Summary shows teams/matches fetched

### 10.3) Single Season Ingestion
```bash
npm run ingest -- --season 2023-2024
```
**Expected:**
- ~20 teams upserted
- ~380 matches upserted
- ~760 TeamMatchStats records created
- No errors (or only minor warnings)

### 10.4) Idempotency Test
```bash
npm run ingest -- --season 2023-2024
# Run again immediately
npm run ingest -- --season 2023-2024
```
**Expected:**
- Second run completes quickly (updates, not inserts)
- Record counts unchanged
- No duplicate errors

### 10.5) Database Inspection
```bash
cd packages/db
npm run db:studio
```
**Expected:**
- Team table: ~20 EPL teams
- Match table: ~380 matches for season
- TeamMatchStats table: ~760 records (2 per match)
- All foreign keys valid
- No null values in required fields

---

## 11) Test Plan

### Unit Tests
```typescript
// normalize.test.ts
describe("computeResult", () => {
  it("returns W when goalsFor > goalsAgainst", () => {
    expect(computeResult(3, 1)).toBe("W");
  });

  it("returns D when goalsFor === goalsAgainst", () => {
    expect(computeResult(2, 2)).toBe("D");
  });

  it("returns L when goalsFor < goalsAgainst", () => {
    expect(computeResult(0, 2)).toBe("L");
  });
});

describe("normalizePercentage", () => {
  it("converts string percentage to float", () => {
    expect(normalizePercentage("45%")).toBe(45);
    expect(normalizePercentage("45.5%")).toBe(45.5);
  });

  it("handles numeric input", () => {
    expect(normalizePercentage(45)).toBe(45);
  });

  it("returns null for invalid input", () => {
    expect(normalizePercentage(null)).toBeNull();
    expect(normalizePercentage("invalid")).toBeNull();
  });
});
```

### Integration Tests (Optional for MVP)
- Mock API responses, test full ingestion flow
- Verify database state after ingestion
- Test error handling (invalid API key, malformed responses)

### Manual Testing Checklist
- [ ] API key configured correctly
- [ ] Database connection works
- [ ] Teams fetched and stored
- [ ] Matches fetched and stored
- [ ] Statistics fetched and stored
- [ ] Possession normalized correctly
- [ ] Result computed correctly (W/D/L)
- [ ] Idempotency works (rerun doesn't create duplicates)
- [ ] Error handling works (invalid API key, network timeout)
- [ ] Logging provides useful information
- [ ] Summary report accurate

---

## 12) Risks & Edge Cases

### Risks
1. **API Rate Limits:** Mitigated by paid tier or batching over multiple days
2. **API Changes:** Provider may change response format (add versioning, monitor changelog)
3. **Missing Data:** Some matches may lack statistics (handle gracefully with nulls)
4. **Data Quality:** Provider data may have errors (log warnings, don't block ingestion)
5. **Database Constraints:** Foreign key violations if teams not created first (ensure team ingestion runs first)

### Edge Cases
1. **Postponed Matches:** Status may change from scheduled → finished later (handle with upserts)
2. **Abandoned Matches:** May have partial stats (store what's available, mark status appropriately)
3. **Duplicate Team Names:** Different teams with same name (use provider ID as primary key)
4. **Missing Possession Data:** Some providers don't track possession for all matches (set to null)
5. **xG Unavailable:** Expected goals may not be available for older seasons (optional field, set to null)
6. **Same Team Playing Itself:** Shouldn't happen in real data, but not prevented at schema level (log warning if detected)

---

## 13) Out of Scope

- Automated scheduling (cron, task queues)
- Real-time/live data ingestion
- Multiple leagues (only EPL for MVP)
- Incremental updates (full re-ingestion each run)
- Retry logic with exponential backoff
- Data archival or historical snapshots
- Player-level statistics
- Odds data
- Advanced data quality metrics (beyond basic validation)
- Performance optimization (parallel requests, connection pooling)
- Monitoring/alerting (e.g., Sentry, DataDog)

---

## 14) Success Criteria Summary

This PR is complete when:
1. ✅ Worker application structure exists in `apps/worker/`
2. ✅ API-Football integration configured and working
3. ✅ CLI command runs successfully: `npm run ingest -- --season 2023-2024`
4. ✅ Database populated with:
   - ~20 EPL teams
   - ~380 matches per season
   - ~760 TeamMatchStats records per season
5. ✅ All normalization rules implemented and tested
6. ✅ Idempotency verified (rerun doesn't create duplicates)
7. ✅ Error handling works (logs errors, continues processing)
8. ✅ README.md documents setup, usage, and troubleshooting
9. ✅ All verification steps pass
10. ✅ Tech Lead approves data quality and implementation

---

## 15) Follow-up Work

- **PR #3:** API endpoints (`/teams`, `/seasons`) - will query data ingested here
- **PR #4:** `/trends/run` endpoint - will aggregate TeamMatchStats
- **Future:** Automated scheduling (daily updates)
- **Future:** Incremental ingestion (fetch only new/updated matches)
- **Future:** Multi-league support
- **Future:** Performance optimization (parallel requests, caching)

---

**End of Spec**
