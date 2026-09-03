# DESIGN: Feedback Archive — durable local storage of all submitted feedback

**Status:** scoping only, no implementation. Untracked repo-root design doc.
**Ask:** users want Plannotator to durably store ALL feedback they ever submit, on every surface, as a safe local collection they can learn from and analyze over time.

---

## 1. Recommendation in brief

- **New top-level data-dir namespace** `${PLANNOTATOR_DATA_DIR}/feedback/{project}/` holding an
  append-only **`index.jsonl`** (authoritative, self-contained structured records) plus a
  human-readable **`records/{timestamp}-{surface}-{decision}.md`** sidecar for every record that
  carries content. JSONL for the stated analysis goal; md for grep/browse parity with everything
  else in the data dir. One record per submission, written **at decision-settlement time inside the
  servers** (both runtimes), so every agent frontend (Claude Code, OpenCode, Codex, Copilot CLI,
  Gemini, Kiro, Amp, Droid, Pi) is covered by exactly two implementations.
- **One shared module** `packages/shared/feedback-archive.ts` (schema v1, `appendFeedbackRecord`,
  `renderFeedbackRecordMarkdown`), vendored to Pi via `vendor.sh`. Never throws; write-before-
  draft-delete ordering per the #678 precedent; a failed archive write on code review **keeps the
  draft** as the recovery copy.
- **One new knob**: `PLANNOTATOR_FEEDBACK_HISTORY` env + `feedbackHistory` config key, default
  **enabled**, resolver mirroring `resolveAnnotateHistory` (`packages/shared/config.ts:643`).
  Annotate-surface records additionally honor the existing `PLANNOTATOR_ANNOTATE_HISTORY` opt-out
  so "annotateHistory=0 → fully stateless annotate sessions" stays true.
- **No retention/pruning** (matches plans/, history/, guides/) — said loudly in docs, with the
  privacy note that feedback text and quoted document/code excerpts land on disk.
- **No migration, no behavior change to existing stores**: plans/, history/, and
  history/.../submissions/ keep working exactly as today. The archive is additive.
- `"feedback"` is **added to `PURGE_OWNED_TOP_LEVEL`** (`packages/server/uninstall.ts:89`) — it is
  Plannotator-authored data and must not survive purge (and would otherwise show as an
  unrecognized leftover in dry-run).
- Records carry a `client` field (`"plannotator"`) and reuse the project/slug conventions already
  shared with plannotator-tui's `clients/` namespace, so cross-tool feedback can be unioned by an
  analyzer without any promise to plannotator-tui.

---

## 2. Gap inventory (verified against the code)

Every feedback-submission path across both runtimes, and what each persists today:

### 2.1 Plan review

| Path | Bun | Pi mirror | Persists today |
|---|---|---|---|
| `POST /api/approve` | `packages/server/index.ts:461` | `apps/pi-extension/server/serverPlan.ts` (~line 354) | `saveFinalSnapshot(slug, "approved", plan, feedback)` → `plans/{slug}-approved.md`, plus `{slug}.annotations.md` when feedback present — **but only while the client-sent `planSave.enabled` is true** (user setting, default on, custom path supported). Then `deleteDraft`. |
| `POST /api/deny` | `packages/server/index.ts:547` | serverPlan.ts (~line 406) | Same via `saveFinalSnapshot(..., "denied", ...)`, same `planSave` gate. |
| Plan version history | `saveToHistory` on arrival | same | Always on, independent of `planSave`. Versions only — no decisions. |

**Gap:** if the user turns `planSave` off, plan feedback is gone after the decision. Also the
decision snapshot is a rendered md blob keyed by slug — repeat decisions on the same slug/day
**overwrite** the previous `{slug}-approved.md`/`-denied.md` (same filename), so iterating
approve→deny→approve on one plan keeps only the last snapshot per status. Not analyzable as a
timeline.

### 2.2 Code review — the headline gap

| Path | Bun | Pi mirror | Persists today |
|---|---|---|---|
| `POST /api/feedback` (Send Feedback AND Approve/LGTM — same endpoint, `approved` boolean) | `packages/server/review.ts:3285` | `serverReview.ts:3275` | **Nothing.** `deleteDraft(draftKey, ...)` then `resolveDecision({...})`. The feedback text and annotations exist only in the JSON the CLI prints to the agent (`apps/hook/server/index.ts:1839-1854`). If the agent session timed out or the terminal is gone, the review is lost — the exact failure #678 fixed for annotate. |
| `POST /api/exit` (dismiss) | `review.ts:3277` | `serverReview.ts:3272` | Nothing (contentless by design). |
| `POST /api/pr-action` (submit review to GitHub/GitLab in PR mode) | `review.ts:3311` | `serverReview-pr-action` path | Delivered to the platform; **no local record**. (Failed GitLab comments get a debris file under `failed-comments/` — `packages/shared/pr-gitlab.ts:712` — which is error recovery, not an archive.) |
| Review draft | `/api/draft` | same | Crash recovery only; deleted on submit. |

### 2.3 Annotate

| Session type | Persists today |
|---|---|
| Single local file (`mode === "annotate"`, non-URL — gate `singleFileLocalAnnotate`, `packages/server/annotate.ts:297`) | Durable submit record `history/{project}/{slug}/submissions/{timestamp}.md` written BEFORE draft delete (#678), via `persistAnnotateSubmission` (`packages/shared/annotate-history.ts:134`), called from `/api/approve` (annotate.ts:1137) and `/api/feedback` (annotate.ts:1168). Skipped when `PLANNOTATOR_ANNOTATE_HISTORY=0`. Contentless bare approves skipped. Pi mirror identical (`serverAnnotate.ts:414`). |
| URL sessions | **Never write** (documented invariant). |
| `annotate-last` / message sessions (incl. `opencode-annotate-last`, `copilot-last`) | **Never write.** |
| Live app (`annotate-app`) | **Never write** (documented: no version history, no durable submission records). |
| Folder sessions | Per-file version history via `/api/doc` lazily, but **no submitted-feedback records** (documented). |
| `/api/exit` | Nothing (contentless). |
| Strict gates (`--gate --json`, `--require-approval`, `--result-file`) | Decision record to stdout/result file — caller-owned, not a collection; and single-local-file gates also get the #678 record. |

### 2.4 Delivery variants — why they don't multiply the work

OpenCode, Codex, Copilot, Gemini, Kiro, Amp, and Droid all reach decisions through the same two
server implementations (Bun `packages/server/*`, Pi `apps/pi-extension/server/*`); the variants
differ only in how the CLI/plugin **prints** the decision afterwards (e.g.
`apps/hook/server/index.ts:2012` Copilot permission JSON). Persisting at settlement time inside
`startPlannotatorServer` / `startReviewServer` / `startAnnotateServer` + the three Pi mirrors
covers every origin with zero per-agent code. The `origin` string is already in server scope for
provenance.

### 2.5 External / WebMCP / agent-sourced annotations — include, with provenance

Decision: **include them in the archive record, tagged**. Rationale: the archive records "what was
submitted in this session", and the submitted feedback text the agent received already embeds
them; excluding them would make the record disagree with what was sent. Every externally-created
annotation already carries `source` (e.g. `"eslint"`, `"browser-agent"`, review-agent job sources)
and optionally `author`; the JSONL record preserves both per annotation plus summary counts, so
"my own comments" is a trivial filter (`source == null`). Agent job **outputs** themselves
(guides, tours, review-agent findings never accepted into the session) are NOT archived — they are
not submitted feedback, and guides already persist under `guides/`.

---

## 3. Storage design

### 3.1 Location

```
${PLANNOTATOR_DATA_DIR}/feedback/
  {project}/                      # sanitizeTag'd project name, same convention as history/
    index.jsonl                   # append-only, one JSON object per line, schema v1
    records/
      2026-08-31T14-22-07-511Z-review-feedback.md
      2026-08-31T15-01-33-002Z-plan-denied.md
```

- **Why a new top-level dir and not `history/`:** `history/{project}/{slug}/` is keyed by
  plan-heading or file-path slugs; code review has neither, and shoehorning a synthetic slug in
  would pollute the version-scan invariants (`getNextVersionNumber`/`listVersions` match `NNN.md`
  directly in the slug dir; the `submissions/` subdir exists precisely to stay out of that scan —
  `packages/shared/storage.ts:276` comment). A flat per-project timeline is also what "analyze my
  behavior over time" wants.
- **Why not under `clients/plannotator/`:** `clients/` is the namespace granted to *external*
  tools (plannotator-tui at `clients/plannotator-tui/annotations/{project}/{slug}/annotations.json`,
  verified on disk); Plannotator's own stores are top-level (`plans/`, `history/`, `guides/`).
  Uninstall purge deliberately does not touch `clients/` (other tools' data); `feedback/` must be
  purged, hence top-level + `PURGE_OWNED_TOP_LEVEL`.
- Filenames use the `saveAnnotateSubmission` stamp convention (ISO with `:`/`.` → `-`, collision
  counter `-2`, `-3`…).
- The module must resolve the data dir **per call** (call `getPlannotatorDataDir()` inside the
  function), not as a module-level const like `storage.ts:16` does — the Bun single-process test
  rule means a module-load capture cannot be redirected to a temp `PLANNOTATOR_DATA_DIR` by tests
  without import-order games.

### 3.2 Format: JSONL index + md sidecar (both, one code path)

Recommended shape: **JSONL is authoritative and self-contained** (a record can be analyzed without
opening the sidecar); the md sidecar is the same human-readable exported feedback the agent
received, with a small metadata header — written only when the record has content (bare
approvals/LGTMs get a JSONL line only). Rationale: the stated goal is analysis over time (JSONL:
`jq`, DuckDB, a future UI), while everything else in the data dir is md and users explicitly asked
to grep their own comments (sidecar). The duplication is small (feedback is text) and buys a
one-pass read path for tools and a pleasant one for humans. Rejected alternatives: md-only (forces
every analyzer to re-parse prose; annotation structure lost), JSONL-only (breaks the grep/browse
habit the rest of the data dir set), SQLite (new dependency, single-writer questions across two
runtimes and concurrent servers — JSONL append with `O_APPEND` semantics is atomic enough for
line-sized records and degrades to "a torn last line" not a corrupted store; readers skip
unparsable lines).

### 3.3 Record schema (v1)

```jsonc
{
  "v": 1,
  "ts": "2026-08-31T14:22:07.511Z",
  "client": "plannotator",                  // interop field, see §8
  "project": "plannotator",                 // sanitizeTag'd, same as history/ key
  "origin": "claude-code",                  // detected agent origin
  "surface": "review",                      // "plan" | "review" | "annotate" | "annotate-url"
                                            //  | "annotate-app" | "annotate-last" | "annotate-folder"
  "decision": "feedback",                   // "approved" | "approved-with-notes" | "denied"
                                            //  | "feedback" | "lgtm" | "pr-review" | "dismissed"
  "target": {                               // surface-specific identity
    "slug": "my-plan-2026-08-31",           // plan: history slug + version at decision time
    "planVersion": 3,
    "filePath": "/abs/path.md",             // annotate single-file/folder-file
    "url": "https://…",                     // annotate-url / annotate-app targetUrl
    "review": { /* §4 */ }                  // code review identity
  },
  "feedback": "…full exported feedback text, byte-identical to what the agent received…",
  "annotations": [                          // structured, from the submit body (review + annotate;
    {                                       // plan submits only rendered text — omitted there)
      "id": "…", "type": "COMMENT",
      "text": "user's comment", "originalText": "quoted selection",
      "file": "packages/server/review.ts", "line": 3285, "side": "new",   // review annotations
      "source": null, "author": "ramos", "inReplyTo": null,
      "diffContext": null
    }
  ],
  "counts": { "annotations": 4, "external": 1, "images": 0 },
  "recordFile": "records/2026-08-31T14-22-07-511Z-review-feedback.md"   // absent for decision-only lines
}
```

Notes:
- Image attachments are referenced by their existing temp paths in the feedback text, not copied
  into the archive (v1; copying is a severable increment — temp paths rot, note in docs).
- Bare decisions (approve-without-notes, LGTM, plan approve with no feedback, and — optionally —
  dismiss/exit) are recorded as **decision-only JSONL lines** (no sidecar): cheap, and approval/
  dismissal rates are exactly the behavior data users asked to analyze. `/api/exit` recording is
  marked optional-v1 below; everything else contentless-skips today and the archive should not
  silently diverge without a line item.
- The annotations array is passed through as submitted (they are already `unknown[]` on the
  server); the module shallow-normalizes known fields and never throws on unexpected shapes.

### 3.4 Write ordering and failure policy (the #678 contract, generalized)

1. Build record → append JSONL line → write sidecar (content records).
2. Only then `deleteDraft` and `resolveDecision`.
3. On archive-write failure: **log a one-line warning and (review + annotate) keep the draft** as
   the recovery copy — return "not durable" to the handler exactly like
   `persistSubmittedDecision`'s boolean (`annotate.ts:376-397`). Plan flow: log and proceed
   (planSave already persisted the decision when enabled; do not block a plan approval on disk).
4. `appendFeedbackRecord` never throws (matches `computeAnnotateHistory` / `persistAnnotateSubmission`).

---

## 4. What a code-review feedback record contains

The review server has everything needed in scope at `/api/feedback` time
(`review.ts:320-372`): `currentDiffType`, `currentBase`, `currentGitRef`, `currentPatch`,
`snapshotId`/fingerprint, `gitContext` (vcsType, cwd), `prMetadata`, `workspace`, `origin`.

`target.review` (v1):

```jsonc
{
  "vcsType": "git",                       // git | jj | gitbutler | p4 | none (piped patch)
  "diffType": "since-base",               // incl. commit:<sha> family, workspace modes
  "base": "origin/main",
  "gitRef": "abc1234",                    // HEAD at capture
  "snapshotId": "…",                      // ties record to the diff snapshot reviewed
  "cwd": "/abs/repo",
  "pr": { "provider": "github", "repo": "o/r", "number": 123 },   // PR mode only
  "changedFiles": 14, "patchBytes": 48211  // size metadata only
}
```

- **NOT the full patch by default.** Precedent: guide history stores full patches and the docs had
  to flag it loudly (`PLANNOTATOR_GUIDE_HISTORY` table entry); here nothing needs to re-render the
  diff later, so identity (refs + snapshotId) suffices — the user can regenerate the diff from
  their repo. A `feedbackHistoryIncludePatch`-style opt-in is a *possible* later increment, not
  scoped.
- Per-annotation `file`/`line`/`side` come from the review annotation objects the client already
  submits; severity is whatever the annotation `type`/labels carry — no new taxonomy invented.
- Decision values: `lgtm` (approved, empty feedback), `approved-with-notes`, `feedback`
  (changes requested), `pr-review` (submitted to the platform via `/api/pr-action` — archived too:
  it is user-authored feedback that otherwise only lives on GitHub), `dismissed` (optional).

---

## 5. Controls

- **`PLANNOTATOR_FEEDBACK_HISTORY`** env (`0`/`false` disables) + **`feedbackHistory`** config key,
  env > config > default **true**. New `resolveFeedbackHistory(config)` in
  `packages/shared/config.ts` beside `resolveAnnotateHistory` (line 643), same coercion. A separate
  knob (not folded into `PLANNOTATOR_ANNOTATE_HISTORY`) because the semantics differ:
  annotateHistory governs *copying annotated content*; feedbackHistory governs *the user's own
  submissions*, and code-review users must be able to control it without touching annotate.
- **Interaction, stated as invariants:**
  - `feedbackHistory=0` → no archive writes anywhere. Legacy stores (planSave snapshots, #678
    submissions) are **unaffected** — this knob governs only the new archive.
  - `annotateHistory=0` → additionally suppresses archive records for ALL annotate surfaces
    (single-file, folder, URL, app, last), preserving the documented "fully stateless annotate
    sessions" promise verbatim.
  - **Behavior change to document loudly:** with defaults, URL / annotate-last / live-app /
    folder-session submissions now leave a durable record for the first time (that is the ask).
    Release-note it; the CLAUDE.md env table and marketing docs both get entries.
- **No retention/pruning by default** — consistent with plans/, history/, guides/ ("nothing prunes
  the directory otherwise"). Docs must say so in the same breath as the privacy note: *submitted
  feedback text, quoted document/code excerpts, and annotation metadata are written to
  `~/.plannotator/feedback/` and kept indefinitely; delete the directory (or a project subdir) to
  forget; set the knob to 0 to never write.*
- Uninstall: add `"feedback"` to `PURGE_OWNED_TOP_LEVEL` (`uninstall.ts:89`) so purge removes it
  and dry-run recognizes it.

## 6. Read path

- **v1 (scoped):** files on disk. `index.jsonl` is `jq`-able; `records/*.md` are greppable. Docs
  show two worked one-liners (e.g. deny-rate by month; most-annotated files). That satisfies the
  stated ask.
- **Named later increments (not scoped, do not design now):**
  1. `plannotator feedback list [--project X] [--json]` CLI reader.
  2. Archive-tab integration: the plan sidebar's Archive browser already exists
     (`archive-mode.ts`, `/api/archive/*`) — a "Feedback" section listing records is a natural
     follow-on, plus a review-side equivalent.
  3. Image attachment copying into `feedback/{project}/assets/`.
  4. Opt-in full-patch retention for review records.
  5. Analytics surface (explicitly out of scope per the ask).

## 7. Both runtimes — exact touch points

**New shared module (single source of truth):**
- `packages/shared/feedback-archive.ts` — schema types, `appendFeedbackRecord(input): string | null`,
  `renderFeedbackRecordMarkdown`, per-call data-dir resolution, never-throw. (~200–250 lines)
- `packages/shared/feedback-archive.test.ts` (~150–200 lines)
- `apps/pi-extension/vendor.sh` — add `feedback-archive` to the packages/shared vendor list
  (line 32 loop). It imports only `data-dir`, `project`, `config` siblings → flat-rewrite safe.

**Config:**
- `packages/shared/config.ts` — `feedbackHistory?: boolean` on `PlannotatorConfig` (+ doc comment),
  `resolveFeedbackHistory()`. (~25 lines) Pi picks it up via the existing `config` vendor entry.

**Bun servers:**
- `packages/server/index.ts` — `/api/approve` (~line 529) and `/api/deny` (~line 573): build +
  append record before `deleteDraft`. (~20 lines)
- `packages/server/review.ts` — `/api/feedback` (~line 3285): record before `deleteDraft`, keep
  draft on failed write; `/api/pr-action`: record on successful platform submit; optional
  `/api/exit` decision-only line. Needs `origin`/project threading (server options already carry
  `origin`; project via `detectProjectName` result passed from the CLI or re-derived from
  `gitContext.cwd`). (~40–60 lines)
- `packages/server/annotate.ts` — extend `persistSubmittedDecision` (~line 376): keep the legacy
  #678 write untouched, add the archive append for all annotate modes under the gate rules in §5.
  (~25 lines)
- `packages/server/uninstall.ts` — `PURGE_OWNED_TOP_LEVEL` + `"feedback"`. (1 line + test list update)

**Pi mirrors (same edits, vendored module):**
- `apps/pi-extension/server/serverPlan.ts` (~line 406 region)
- `apps/pi-extension/server/serverReview.ts` (~line 3275 region + pr-action path)
- `apps/pi-extension/server/serverAnnotate.ts` (~line 414 region)
- (~60–90 lines total; Pi has no `--tailscale` but that does not affect archiving)

**Docs:**
- CLAUDE.md env table + plan/annotate/review flow notes; `apps/marketing` env-var reference page;
  release notes entry flagging the new-writes behavior change.

## 8. Interop with plannotator-tui (`clients/` namespace)

Observed on-disk contract (verified): `~/.plannotator/clients/{client-id}/annotations/{project}/{slug}/annotations.json`
with `annotations[]` (anchor/quote/kind/body/timestamps) and `deliveries[]` (when/where sent) —
project and slug follow this repo's `sanitizeTag` + `deriveAnnotateHistorySlug` conventions, which
is what already makes cross-tool data land in compatible buckets.

Design-compatibly, promise nothing:
- **Shared directory convention, not a shared store.** Plannotator's archive lives in `feedback/`;
  client tools keep `clients/{id}/…`. A future analyzer unions
  `feedback/{project}/index.jsonl` with any `clients/*/feedback/{project}/index.jsonl` a client
  chooses to write.
- **Shared record schema is the offer:** the v1 JSONL schema (§3.3) carries `v` and `client`
  precisely so a client tool MAY emit the same line shape under its own namespace and records
  merge cleanly (sort by `ts`, filter by `client`). Document the schema in the marketing docs
  reference as informational; do not version-negotiate, do not read their files in v1.
- Their existing `annotations.json` working-state files are a different artifact (live annotation
  state + deliveries, not submitted-feedback records) — leave untouched, no adapter in v1.

## 9. Effort estimate, tests, severability

**Size:** ~10 production files touched + 1 new module; ~350–450 new production lines, ~250–350
test lines, plus docs. No UI changes in v1. No build-order implications (server-only).

**Test plan (each guards a nameable regression, per Testing Rules; all under temp
`PLANNOTATOR_DATA_DIR`, env mutated inside tests with restore):**
1. *Review feedback lost again:* submitting review feedback appends exactly one parseable JSONL
   record + sidecar containing the submitted feedback text; on a forced write failure the draft
   survives (regression target: the pre-#678 failure mode recurring on review).
2. *Opt-out ignored:* `PLANNOTATOR_FEEDBACK_HISTORY=0` (and `feedbackHistory:false`) → zero files
   under `feedback/`; legacy planSave/#678 writes unchanged.
3. *Stateless-annotate promise broken:* `PLANNOTATOR_ANNOTATE_HISTORY=0` → no archive record from
   any annotate surface even with feedbackHistory on.
4. *Index corruption:* successive appends never rewrite earlier lines; a record with newlines in
   feedback still serializes to one line; collision-stamped sidecar filenames never overwrite.
5. *Disk-growth regression:* a review record for a large patch contains diff identity +
   size metadata but not the patch bytes.
6. *Purge gap:* uninstall purge removes `feedback/`; dry-run lists it as recognized
   (extend `uninstall.test.ts` fixture list).
7. *Pi parity:* mirror suites (`annotate-submission.test.ts` pattern) assert the same three
   handlers write the same record shape.

**Severable increments (each shippable alone):**
1. **Core + code review** (the actual gap): shared module, config knob, review handlers, both
   runtimes, uninstall, docs. — the minimum worth shipping.
2. Plan approve/deny records.
3. Annotate archive records (all session types) incl. the annotateHistory interaction.
4. Decision-only lines for bare approvals/LGTM/dismiss.
5. `pr-action` records.
6. Read-path increments (§6) and image copying — later, separately.

## 10. Open questions for the maintainer

1. Record `/api/exit` dismissals as decision-only lines, or keep contentless-skip parity? (Lean:
   record them; dismissal rate is behavior data. Cheap either way.)
2. Should plan records also embed the structured annotations? The plan client currently submits
   only rendered feedback text; capturing structure would need a client payload addition (small,
   but touches the UI and both built HTMLs — build-order note applies). v1 scopes text-only.
3. Is `feedback` the right top-level name, or `submissions`? (`feedback/` chosen: matches the
   endpoint names and doesn't collide with the history submissions/ subdir concept.)
