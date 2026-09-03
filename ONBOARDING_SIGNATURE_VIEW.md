# Onboarding: the Signatures view (from scratch)

You are building a new code-review lens for Plannotator: a collapsed "Signatures" view of a diff that shows what changed at the API surface (function and method signatures) without the noise of every body line. The concept was validated in a July 2026 spike with real numbers: across three large merged commits, 4,275 diff lines compressed to 134 signature-relevant lines, a 97% reduction. The feature has never shipped. A previous attempt was abandoned, and the reasons it died are the most valuable input you have. Read this whole document before writing code.

You are expected to do this from scratch. The old code is reference material, not a foundation.

## 1. What Plannotator is, in one paragraph

Plannotator intercepts plan approvals and code reviews for AI coding agents. The code-review side captures a local VCS diff (git, jj, GitButler, P4), serves it to a browser UI, and lets a human annotate it; annotations are exported as structured feedback the agent acts on. The annotation round trip is the product. Any view that renders code the user cannot comment on, or comments that cannot be traced back to real file locations, is decoration. This rule killed the first Signatures attempt.

## 2. Orientation: what to read first

- `CLAUDE.md` (symlink of `AGENTS.md`) at the repo root: project structure, server API, build order, testing rules. Non-negotiable reading, especially "Testing Rules" and the build-order warnings.
- `packages/review-editor/App.tsx`: the review UI shell. Large. You do not need all of it; find how diff data arrives (`/api/diff`), how diff types switch (`fetchDiffSwitch`), and how the dock panels mount.
- The diff rendering pipeline: we render patches with the `@pierre/diffs` library. Find where `FileDiff` components consume patch text. Pierre expects real, well-formed patches; feeding it synthetic ones is how the old attempt crashed ("Provided patch must contain exactly 1 file diff").
- The annotation model: `packages/ui/types.ts` (Annotation), and `packages/review-editor/utils/exportFeedback.ts` for how review feedback is exported.
- PR #1277 (Call Flow navigation and annotations): the closest shipped precedent. Call Flow rows are synthetic (inferred call paths, not diff hunks), and #1277 solved the "comment on synthetic content" problem by making every row commentable and demoting out-of-hunk or source-less targets to file-scoped or review-scoped feedback with full target context preserved. Study `packages/review-editor/utils/callFlowAnnotations.ts` on that branch. You will want the same demotion pattern.
- Existing analysis layers, for positioning and precedent: the `sem` semantic-diff sidecar (`/api/semantic-diff`) and CallDiff (`/api/call-flow`, PR #1268, #1270, #1271). Signatures is a third lens, not a replacement for either.
- Server: `packages/server/review.ts`. Note the snapshot model (`snapshotId`, `/api/diff/fresh`) and the single-flight caching used by `getSemanticDiff`. If you add a server endpoint, the two-runtime law applies: Bun (`packages/server/`) and the Pi Node mirror (`apps/pi-extension/server/`) must both be updated, with shared logic in `packages/shared/` vendored via `apps/pi-extension/vendor.sh`.

## 3. History: what was tried, what happened

### The July 2026 attempt (never committed, never shipped)

Branch `feat/signature-diff`, local worktree at `/Users/ramos/plannotator/feat-signature-diff`. About 700 lines of working implementation sit UNCOMMITTED there: a tree-sitter based stubber (`packages/shared/signature-stub.ts`), a patch synthesizer (`signature-patch.ts`), a server endpoint, client hook, and a "Signatures" toolbar button. Treat it as an artifact to study, not code to resurrect. Its architecture is the thing that failed.

The architecture: stub every function body down to `{ ... }` on both revisions, text-diff the stubs, and feed the synthetic patch through the normal rendering pipeline as a separate diff type.

Why it died, in order of importance:

1. **Annotations could not anchor.** The stubbed document exists in no real file. Comments on it had no path back to real file lines, and no demotion model existed yet (#1277 came later). A read-only lens in an annotation tool is a dead end. This was the true killer.
2. **Crashes on some files.** The synthesized patches violated Pierre's expectations (`FileDiff: Provided patch must contain exactly 1 file diff`).
3. **Rendering read as all-green.** Deletions were not visibly represented; the maintainer flagged it in the last session before abandoning the branch.
4. **It was orphaned, not rejected.** The maintainer got pulled onto the git-status view work mid-demo. There was no final verdict. The concept is still wanted.

The design and decision history is preserved in session transcripts at `~/.claude/projects/-Users-ramos-plannotator-feat-signature-diff/` if you need primary sources.

### The ast-grep evaluation (rejected then, re-evaluate now)

ast-grep's `outline` subcommand (alpha in v0.44.x, July 2026) was benchmarked as the extraction engine over 18 real `.ts`/`.tsx` files and rejected on evidence:

- **First-line truncation dropped real signature changes.** The canonical failure: `PanelViewToggle.tsx` gained two props inside an inline multi-line `React.FC<{...}>` type; ast-grep's outline showed neither, because it truncated the signature to its first line. `--json` had the same limitation.
- **Line-number gutters poisoned diffs.** Un-stripped outline diffs were sometimes larger than the real diff (one insertion renumbers every later declaration).
- **Structural concerns**: alpha output format explicitly unstable, outlines snapshots rather than diffs, and shelling out to an external binary the review pipeline does not control.

**Your first task is to re-run this evaluation.** ast-grep iterates fast and more than a month has passed. Check the current release notes and re-test the two blocking behaviors specifically: multi-line signature fidelity (use the `PanelViewToggle` prop-addition case as the litmus test) and whether line metadata can be kept out-of-band. If ast-grep outline now emits full signature spans with stable output, the engine question reopens. If not, the July conclusion stands: an in-process tree-sitter library binding (the old attempt used `web-tree-sitter` + `tree-sitter-typescript` wasm) beats an external alpha binary. Also weigh a third option that did not exist in July: CallDiff already ships a managed tree-sitter runtime with per-language grammar packs and an install UX (PR #1270/#1271). Sharing that runtime would avoid a second grammar-distribution mechanism, at the cost of coupling to an opt-in feature. Bring a recommendation, not just data.

## 4. The architectural reframe: fold, do not stub

The recommended direction, agreed with the maintainer in design discussion (August 2026): do not synthesize a signature document. **Collapse the real diff in the renderer.**

- The Signatures view is a fold state of the normal diff, not a separate diff type. Function bodies collapse to their signature line plus a pill: `⌄ +12 −4 inside`.
- Every visible line is a genuine diff line. Annotation anchoring, add/remove coloring, and the existing rendering pipeline all keep working because nothing synthetic exists. The crash class and the all-green problem disappear by construction.
- Fold state is a gradient, not a mode. Fully folded is the signatures overview; clicking a pill expands that one body in place. This turns the lens into a review workflow: skim the API surface, dive where it smells.
- Commenting on a folded pill either auto-expands the body for line selection or produces a function-scoped comment using the #1277 demotion pattern (function identity as the anchor, full context in the export).
- What the engine must produce shrinks accordingly: not stubbed documents, just **function ranges** (file, identifier, full signature span, body span) for both revisions, mapped onto rendered diff rows.

Two hard requirements survive from the spike, now as tests rather than lessons:

- Never truncate a signature to its first line. Multi-line signatures must be emitted or displayed in full.
- Line metadata lives out-of-band, never inline in content that gets diffed or rendered.

And one honest limitation to design around, not against: signature folding gives nothing on monolithic files. `packages/review-editor/App.tsx` is a ~3,000-line component; three large commits produced 0 to 3 signature lines there because the churn is inside one body. Wide, shallow diffs compress by 97%; deep, narrow diffs compress to nothing. Call Flow covers that blind spot; do not try to make Signatures do it.

## 5. Open architecture questions (bring proposals)

1. **Where do ranges get computed?** Server-side (snapshot-keyed cache, single-flight, two-runtime mirror required) versus client-side in the browser (web-tree-sitter wasm against `/api/file-content`, no server change at all). Client-side is worth serious consideration: it needs no Pi mirror and no endpoint, and the review UI already fetches full file contents for expandable context.
2. **Grammar delivery.** If in-process wasm: how grammars ship inside the single-file build (`bun build --compile` embedding was the unresolved question of the July attempt). If CallDiff runtime reuse: how the dependency behaves when the user has not opted into Call Flow. If ast-grep: how the binary is discovered and what happens when absent (the code-nav precedent chose ripgrep in May 2026 specifically because it is always available; graceful absence is mandatory).
3. **Scope of language support.** TS/TSX first is fine. The design should name how a second language gets added, and must not silently misrepresent files it cannot parse (render them unfolded, never wrongly folded).
4. **Where the toggle lives.** Probably alongside the existing view controls rather than as a diff type; folding composes with any diff type (uncommitted, since-base, commit views). Confirm with the maintainer before building UI.
5. **A shared range-overlay seam (stretch).** Signatures folds ranges; Call Flow links ranges; sem classifies ranges. If a single "AST ranges projected onto diff rows" seam falls out of this work naturally, take it; do not force it in v1.

## 6. Working agreements

- Read `AGENTS.md` Testing Rules before writing any test. No prose snapshots, no round-trip prop tests; pin behavior that can regress. Bun runs all test files in one process: no module-scope env or global mutation, sandbox any data-dir use under a temp `PLANNOTATOR_DATA_DIR`, and never touch the real `~/.plannotator`.
- Build order matters: review UI changes require `bun run --cwd apps/review build && bun run build:hook` before the compiled binary reflects them.
- New directories with Tailwind classes need an `@source` entry in the app's `index.css`.
- PRs: TLDR first, findings and rationale in plain prose, an "AI-assisted" note when applicable, and no em dashes in any GitHub-facing text.
- Small, reviewable PRs beat one monolith. A reasonable arc: engine re-evaluation report; fold-rendering MVP behind a toggle (no annotations on folds yet); folded-region commenting with the demotion pattern; polish and docs.

## 7. Quick reference: the prior artifacts

| Artifact | Location | Status |
|---|---|---|
| Old implementation (~700 lines) | worktree `/Users/ramos/plannotator/feat-signature-diff` | Uncommitted, at risk, reference only |
| Design spec + decision history | `~/.claude/projects/-Users-ramos-plannotator-feat-signature-diff/*.jsonl` | Primary sources, includes the ast-grep spike report |
| ast-grep litmus test | `PanelViewToggle.tsx` prop addition inside inline `React.FC<{...}>` | Re-run against current ast-grep |
| Annotation demotion precedent | PR #1277, `callFlowAnnotations.ts` | Study before designing fold comments |
| Analysis-layer precedents | sem sidecar, CallDiff (PRs #1268, #1270, #1271) | Positioning + runtime-reuse option |
| Code-nav availability precedent | `/api/code-nav/resolve` (ripgrep, May 2026) | Why "always works" beats "richer but absent" |
