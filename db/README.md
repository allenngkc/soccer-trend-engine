# @repo/db

Database package for Soccer Trend Terminal. Contains Prisma schema, client, and migration utilities.

## Overview

This package provides:
- Prisma schema defining core tables (Team, Match, TeamMatchStats)
- Type-safe Prisma Client for database queries
- Migration management scripts
- Database utilities

## Setup

### 1. Install Dependencies

```bash
cd packages/db
npm install
```

### 2. Configure Database Connection

Create a `.env` file in this directory. Prisma v7 reads `DATABASE_URL` from `prisma.config.ts`, which loads `.env`:

```bash
cp .env.example .env
```

Edit `.env` and set your PostgreSQL connection string:

```
DATABASE_URL="postgresql://user:password@localhost:5432/soccer_trends?schema=public"
```

### 3. Generate Prisma Client

```bash
npm run db:generate
```

This generates the Prisma Client based on your schema.

### 4. Run Migrations

For development (creates and applies migration):

```bash
npm run db:migrate:dev --name init
```

For production (applies existing migrations):

```bash
npm run db:migrate:deploy
```

## Common Operations

### Generate Prisma Client

After schema changes, regenerate the client:

```bash
npm run db:generate
```

### Create a New Migration

```bash
npm run db:migrate:dev --name <migration_name>
```

Example:
```bash
npm run db:migrate:dev --name add_team_logo
```

### Apply Migrations (Production)

```bash
npm run db:migrate:deploy
```

### Push Schema Without Migration

For prototyping (not recommended for production):

```bash
npm run db:push
```

### Open Prisma Studio

Visual database browser:

```bash
npm run db:studio
```

Opens at http://localhost:5555

### Reset Database

**WARNING: Deletes all data**

```bash
npm run db:reset
```

## Usage in Other Packages

Import the Prisma client and types:

```typescript
import { prisma, Team, Match, TeamMatchStats } from '@repo/db';

// Query teams
const teams = await prisma.team.findMany();

// Create a match
const match = await prisma.match.create({
  data: {
    competition: 'EPL',
    season: '2024-2025',
    matchDate: new Date(),
    homeTeamId: 1,
    awayTeamId: 2,
    status: 'scheduled'
  }
});
```

## Schema Overview

### Team
- Core team information (name, country, league)
- Relations to matches (home/away) and stats

### Match
- Match metadata (competition, season, date)
- Home/away team references
- Final score (homeGoals, awayGoals)
- Status: scheduled | finished

### TeamMatchStats
- Per-team match statistics
- Core stats: goalsFor, goalsAgainst, result (W/D/L)
- Optional stats: possession, corners, shots, xG, fouls, cards
- Unique constraint on (matchId, teamId)

## Migration Workflow

### Development
1. Modify `prisma/schema.prisma` (connection URL is configured in `prisma.config.ts`)
2. Run `npm run db:migrate:dev --name <description>`
3. Prisma creates migration file and applies it
4. Commit both schema and migration files

### Production
1. Pull latest code (includes migrations)
2. Run `npm run db:migrate:deploy`
3. Migrations apply automatically

## Troubleshooting

### "Prisma Client not generated"
Run: `npm run db:generate`

### "Can't reach database server"
- Check DATABASE_URL in .env
- Ensure PostgreSQL is running
- Verify connection credentials

### "Migration failed"
- Check migration SQL in `prisma/migrations/`
- Manually fix database if needed
- Use `npm run db:reset` to start fresh (dev only)

### Type errors after schema change
1. Run `npm run db:generate`
2. Restart TypeScript server in your editor

## Scripts Reference

| Script | Description |
|--------|-------------|
| `db:generate` | Generate Prisma Client from schema |
| `db:migrate:dev` | Create and apply migration (dev) |
| `db:migrate:deploy` | Apply existing migrations (prod) |
| `db:push` | Push schema without migration (prototype) |
| `db:studio` | Open Prisma Studio GUI |
| `db:reset` | Reset database (deletes all data) |

## Additional Resources

- [Prisma Documentation](https://www.prisma.io/docs)
- [Prisma Schema Reference](https://www.prisma.io/docs/reference/api-reference/prisma-schema-reference)
- [Prisma Client API](https://www.prisma.io/docs/reference/api-reference/prisma-client-reference)
