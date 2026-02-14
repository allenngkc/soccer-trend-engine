-- CreateEnum
CREATE TYPE "MatchStatus" AS ENUM ('scheduled', 'finished');

-- CreateEnum
CREATE TYPE "MatchResult" AS ENUM ('W', 'D', 'L');

-- CreateTable
CREATE TABLE "Team" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "country" TEXT,
    "league" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Team_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Match" (
    "id" SERIAL NOT NULL,
    "competition" TEXT NOT NULL,
    "season" TEXT NOT NULL,
    "matchDate" TIMESTAMP(3) NOT NULL,
    "homeTeamId" INTEGER NOT NULL,
    "awayTeamId" INTEGER NOT NULL,
    "homeGoals" INTEGER,
    "awayGoals" INTEGER,
    "status" "MatchStatus" NOT NULL DEFAULT 'scheduled',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Match_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TeamMatchStats" (
    "id" SERIAL NOT NULL,
    "matchId" INTEGER NOT NULL,
    "teamId" INTEGER NOT NULL,
    "isHome" BOOLEAN NOT NULL,
    "goalsFor" INTEGER NOT NULL,
    "goalsAgainst" INTEGER NOT NULL,
    "result" "MatchResult" NOT NULL,
    "possession" DOUBLE PRECISION,
    "corners" INTEGER,
    "shots" INTEGER,
    "shotsOnTarget" INTEGER,
    "xg" DOUBLE PRECISION,
    "xga" DOUBLE PRECISION,
    "fouls" INTEGER,
    "yellow" INTEGER,
    "red" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TeamMatchStats_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Match_competition_season_matchDate_idx" ON "Match"("competition", "season", "matchDate");

-- CreateIndex
CREATE INDEX "TeamMatchStats_teamId_matchId_idx" ON "TeamMatchStats"("teamId", "matchId");

-- CreateIndex
CREATE INDEX "TeamMatchStats_teamId_idx" ON "TeamMatchStats"("teamId");

-- CreateIndex
CREATE UNIQUE INDEX "TeamMatchStats_matchId_teamId_key" ON "TeamMatchStats"("matchId", "teamId");

-- AddForeignKey
ALTER TABLE "Match" ADD CONSTRAINT "Match_homeTeamId_fkey" FOREIGN KEY ("homeTeamId") REFERENCES "Team"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Match" ADD CONSTRAINT "Match_awayTeamId_fkey" FOREIGN KEY ("awayTeamId") REFERENCES "Team"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TeamMatchStats" ADD CONSTRAINT "TeamMatchStats_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TeamMatchStats" ADD CONSTRAINT "TeamMatchStats_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
