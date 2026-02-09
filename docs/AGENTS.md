
---

# **`docs/AGENTS.md`**

# Agent Team Operating System

This document defines how AI agent teams should collaborate on this project while keeping the human (Tech Lead) in full control.

---

## 0) Philosophy
- Agents propose small, reviewable changes.
- Human approves specs and merges PRs.
- All work follows architecture + conventions.

---

## 1) Workflow (required)
### Step 1: Spec first
- PM/Spec agent writes spec → saved in `docs/specs/`
- Human approves spec before any implementation begins

### Step 2: Small PR slices
- Implementation occurs in small vertical slices
- Agents must respect boundaries (backend vs frontend vs worker)

### Step 3: Review gate
- Reviewer agent reviews PR for correctness + simplicity
- Human Tech Lead gives final approval

---

## 2) PR limits
- Max ~1000 lines changed
- Max 5 files touched
- No new dependencies unless approved

If a task exceeds limits → break into smaller PRs.

---

## 3) Agent roles & boundaries

### A) PM/Spec Agent (no code)
Outputs: specs in Markdown  
Allowed: `docs/specs/*`  
Forbidden: touching code

---

### B) Backend Agent (API)
Responsibilities:
- Implement endpoints
- Validation
- Prisma queries
- Unit tests

Forbidden:
- UI changes
- ETL changes

---

### C) Data/ETL Agent (Worker)
Responsibilities:
- Data ingestion
- Upserts
- Data quality scripts

Forbidden:
- API
- UI

---

### D) Frontend Agent (Web)
Responsibilities:
- Next.js UI components
- Terminal layout
- Wiring up API calls

Forbidden:
- API
- ETL
- Database migrations

---

## 4) Required PR format
Each PR must include:

1. **Plan** (≤ 6 bullets)  
2. **Files changed list**  
3. **Diff only** (no unrelated refactors)  
4. **Verification steps** (commands + expected behavior)  
5. **Tests** (added or justification why not)  
6. **Risks / edge cases**

If any are missing → PR is rejected.

---

## 5) Dependency rule
No new dependency without:
- justification,
- alternatives considered,
- human approval.

---

## 6) Stop conditions (agent must pause & ask human)
- Schema change needed  
- New dependency needed  
- Ambiguous spec  
- PR exceeds limits  
- Conflicting designs  
- Missing provider data  

---