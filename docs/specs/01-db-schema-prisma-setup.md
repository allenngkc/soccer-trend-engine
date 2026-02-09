# Spec: Database Schema & Prisma Setup (PR #1)

**Status:** Draft
**Owner:** PM/Spec Agent
**Approver:** Tech Lead (Human)
**Related:** MVP Overview (00-mvp-overview.md), ARCHITECTURE.md Section 3

---

## 1) User Story

**As a** developer working on the Soccer Trend Terminal,
**I want** a fully configured Prisma schema with core tables (Team, Match, TeamMatchStats),
**So that** I can store and query historical soccer match data efficiently for trend analysis.

---

## 2) Acceptance Criteria

### Must Have
1. ✅ Prisma schema file (`packages/db/prisma/schema.prisma`) with all three core tables defined
2. ✅ All fields from ARCHITECTURE.md Section 3 implemented with correct types
3. ✅ Recommended indexes applied per ARCHITECTURE.md
4. ✅ Foreign key relationships established (Match → Team, TeamMatchStats → Match/Team)
5. ✅ Prisma Client generation configured and working
6. ✅ Initial migration created and can be applied to a fresh Postgres database
7. ✅ Basic package.json scripts for common Prisma operations
8. ✅ README.md in `packages/db/` explaining setup and usage

### Should Have
9. ✅ Timestamps (createdAt, updatedAt) auto-managed by Prisma
10. ✅ Unique constraint on TeamMatchStats(matchId, teamId)
11. ✅ Enum for Match.status ("scheduled" | "finished")
12. ✅ Enum for TeamMatchStats.result ("W" | "D" | "L")

### Won't Have (Out of Scope)
- Seed data (handled in PR #2)
- Database connection pooling configuration
- Migration rollback scripts
- Multi-database support
- Soft deletes or audit logging

---

## 3) Database Schema Details

### 3.1) Team Table
```prisma
model Team {
  id        Int      @id @default(autoincrement())
  name      String
  country   String?
  league    String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  // Relations
  homeMatches      Match[]           @relation("HomeTeam")
  awayMatches      Match[]           @relation("AwayTeam")
  teamMatchStats   TeamMatchStats[]
}
```

**Fields:**
- `id`: Primary key, auto-increment integer
- `name`: Team name (e.g., "Manchester United"), required
- `country`: Optional country code or name
- `league`: Optional league identifier (e.g., "EPL")
- `createdAt`, `updatedAt`: Automatic timestamps

**Indexes:** None required for MVP (small dataset)

---

### 3.2) Match Table
```prisma
enum MatchStatus {
  scheduled
  finished
}

model Match {
  id          Int          @id @default(autoincrement())
  competition String       // e.g., "EPL"
  season      String       // e.g., "2024-2025"
  matchDate   DateTime
  homeTeamId  Int
  awayTeamId  Int
  homeGoals   Int?
  awayGoals   Int?
  status      MatchStatus  @default(scheduled)
  createdAt   DateTime     @default(now())
  updatedAt   DateTime     @updatedAt

  // Relations
  homeTeam       Team              @relation("HomeTeam", fields: [homeTeamId], references: [id])
  awayTeam       Team              @relation("AwayTeam", fields: [awayTeamId], references: [id])
  teamMatchStats TeamMatchStats[]

  @@index([competition, season, matchDate])
}
```

**Fields:**
- `id`: Primary key, auto-increment integer
- `competition`: Competition identifier (e.g., "EPL"), required
- `season`: Season string (e.g., "2024-2025"), required
- `matchDate`: Match date/time, required
- `homeTeamId`, `awayTeamId`: Foreign keys to Team table, required
- `homeGoals`, `awayGoals`: Final score, nullable (null if not finished)
- `status`: Enum ("scheduled" | "finished"), defaults to "scheduled"
- `createdAt`, `updatedAt`: Automatic timestamps

**Indexes:**
- Composite index on `(competition, season, matchDate)` for efficient filtering

**Relations:**
- Two foreign keys to Team (homeTeam, awayTeam)
- One-to-many with TeamMatchStats

---

### 3.3) TeamMatchStats Table
```prisma
enum MatchResult {
  W  // Win
  D  // Draw
  L  // Loss
}

model TeamMatchStats {
  id             Int          @id @default(autoincrement())
  matchId        Int
  teamId         Int
  isHome         Boolean
  goalsFor       Int
  goalsAgainst   Int
  result         MatchResult
  possession     Float?       // 0-100
  corners        Int?
  shots          Int?
  shotsOnTarget  Int?
  xg             Float?       // Expected goals
  xga            Float?       // Expected goals against
  fouls          Int?
  yellow         Int?
  red            Int?
  createdAt      DateTime     @default(now())
  updatedAt      DateTime     @updatedAt

  // Relations
  match Match @relation(fields: [matchId], references: [id])
  team  Team  @relation(fields: [teamId], references: [id])

  @@unique([matchId, teamId])
  @@index([teamId, matchId])
  @@index([teamId])
}
```

**Fields:**
- `id`: Primary key, auto-increment integer
- `matchId`: Foreign key to Match, required
- `teamId`: Foreign key to Team, required
- `isHome`: Boolean indicating if team played at home, required
- `goalsFor`, `goalsAgainst`: Goals scored/conceded, required
- `result`: Enum ("W" | "D" | "L"), required
- `possession`: Possession percentage (0-100), optional
- `corners`: Corner kicks, optional
- `shots`: Total shots, optional
- `shotsOnTarget`: Shots on target, optional
- `xg`: Expected goals, optional
- `xga`: Expected goals against, optional
- `fouls`: Fouls committed, optional
- `yellow`: Yellow cards, optional
- `red`: Red cards, optional
- `createdAt`, `updatedAt`: Automatic timestamps

**Indexes:**
- Unique constraint on `(matchId, teamId)` to prevent duplicates
- Composite index on `(teamId, matchId)` for efficient team-based queries
- Single index on `teamId` for team-specific lookups

**Relations:**
- Foreign key to Match
- Foreign key to Team

---

## 4) Prisma Setup Requirements

### 4.1) Package Structure
```
packages/db/
├── prisma/
│   ├── schema.prisma
│   └── migrations/
│       └── (generated migration files)
├── src/
│   └── index.ts          # Re-export Prisma Client
├── package.json
├── tsconfig.json
└── README.md
```

### 4.2) Prisma Configuration
- **Provider:** PostgreSQL
- **Client output:** Default (`node_modules/.prisma/client`)
- **Preview features:** None required for MVP
- **Generator:** Prisma Client JS

### 4.3) Required Scripts (package.json)
```json
{
  "scripts": {
    "db:generate": "prisma generate",
    "db:migrate:dev": "prisma migrate dev",
    "db:migrate:deploy": "prisma migrate deploy",
    "db:push": "prisma db push",
    "db:studio": "prisma studio",
    "db:reset": "prisma migrate reset"
  }
}
```

### 4.4) Client Wrapper (src/index.ts)
- Export a singleton Prisma Client instance
- Handle connection lifecycle
- Export all Prisma types for use in other packages

Example:
```typescript
import { PrismaClient } from '@prisma/client';

export const prisma = new PrismaClient();
export * from '@prisma/client';
```

### 4.5) Migration Strategy
- Use Prisma Migrate for schema changes
- Initial migration name: `init` or `initial_schema`
- Migrations stored in `packages/db/prisma/migrations/`
- Dev workflow: `db:migrate:dev` (creates + applies migration)
- Production workflow: `db:migrate:deploy` (applies existing migrations)

---

## 5) Environment Variables

Required in `.env` (or environment):
```
DATABASE_URL="postgresql://user:password@localhost:5432/soccer_trends?schema=public"
```

**Note:** Actual connection string provided by Tech Lead during setup.

---

## 6) Dependencies

### New Dependencies Required
```json
{
  "dependencies": {
    "@prisma/client": "^5.x"
  },
  "devDependencies": {
    "prisma": "^5.x"
  }
}
```

**Justification:**
- `@prisma/client`: Runtime client for database queries
- `prisma`: CLI tool for migrations and schema management

**Alternatives Considered:**
- Raw SQL with `pg`: Too low-level, no type safety
- TypeORM: More complex, less TypeScript-native
- Drizzle: Newer, less mature ecosystem

**Decision:** Prisma chosen per ARCHITECTURE.md for type safety and developer experience.

---

## 7) Verification Steps

### 7.1) Schema Validation
```bash
cd packages/db
npm run db:generate
```
**Expected:** Prisma Client generated successfully, no errors.

### 7.2) Migration Creation
```bash
npm run db:migrate:dev --name init
```
**Expected:** Migration file created in `prisma/migrations/`, database schema applied.

### 7.3) Database Inspection
```bash
npm run db:studio
```
**Expected:** Prisma Studio opens, shows three tables (Team, Match, TeamMatchStats) with correct columns.

### 7.4) Type Safety Check
Create a test file:
```typescript
import { prisma } from '@repo/db';

async function test() {
  const team = await prisma.team.create({
    data: { name: 'Test Team' }
  });
  console.log(team.id); // Should have type number
}
```
**Expected:** TypeScript compilation succeeds, autocomplete works.

---

## 8) Test Plan

### Unit Tests (Optional for PR #1)
- Schema validation tests can be added in PR #2 with actual data ingestion
- Focus on manual verification for this foundational PR

### Manual Testing Checklist
- [ ] Prisma Client generates without errors
- [ ] Migration applies to fresh database
- [ ] All three tables exist with correct columns
- [ ] Foreign key constraints work (cannot insert invalid teamId/matchId)
- [ ] Unique constraint on TeamMatchStats(matchId, teamId) prevents duplicates
- [ ] Timestamps auto-populate on insert/update
- [ ] Enums (MatchStatus, MatchResult) accept only valid values
- [ ] Indexes exist (verify with `\d+ table_name` in psql or Prisma Studio)

---

## 9) Risks & Edge Cases

### Risks
1. **Database connection issues:** Mitigated by clear .env documentation
2. **Migration conflicts:** First migration, no conflicts expected
3. **Type generation failures:** Resolved by ensuring Prisma version compatibility

### Edge Cases
1. **Nullable fields:** Optional stats (xg, fouls, etc.) handled with `?` in schema
2. **Duplicate team names:** Allowed (teams differentiated by ID)
3. **Same team playing itself:** Not prevented at schema level (business logic validation in API layer)
4. **Negative stats:** Not prevented at schema level (validation in ingestion layer)

---

## 10) Out of Scope

- Seed data or sample datasets
- Database backup/restore procedures
- Connection pooling configuration (PgBouncer, etc.)
- Read replicas or sharding
- Soft deletes or audit trails
- Database performance tuning beyond indexes
- Multi-tenancy or row-level security

---

## 11) Success Criteria Summary

This PR is complete when:
1. ✅ `packages/db/prisma/schema.prisma` exists with all three models
2. ✅ Initial migration created and applies successfully
3. ✅ Prisma Client generates and exports types
4. ✅ README.md documents setup and common operations
5. ✅ All verification steps pass
6. ✅ Tech Lead approves schema design

---

## 12) Follow-up Work

- **PR #2:** Ingestion pipeline for EPL data (uses this schema)
- **PR #3:** API endpoints (queries via Prisma Client)
- **Future:** Add indexes if query performance degrades with large datasets

---

**End of Spec**
