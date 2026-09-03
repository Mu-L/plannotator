# SPIKE: Bundle optimization theories — killing the 5s plan load

Date: 2026-06-19
Status: Research (read-only). No code changed.
Companion: `SPIKE-bundle-build-and-serve-architecture-20260619-154926.md` (the factual map).
Driver: issue #926 — plan HTML page blank/loading ~5s **every** open (Pi user, macOS/Chrome).

---

## Root cause (one line)

Every plan open serves a ~21 MB HTML (~20.3 MB inlined JS) on a **new random port** with **no cache headers**, parsing everything up front because `viteSingleFile + inlineDynamicImports` forbid code-splitting. New origin per run = cold V8/disk cache every time. **Parse/execute, not network, is the cost.**

There are two independent levers:
- **Cut the JS** (less to parse) — partially cheap.
- **Stabilize the origin** (let the cache survive) — hard, but it's the only thing that kills "every time."

A fix for #926 needs both. They can ship in sequence.

---

## Theories, traced and ranked

### 1. Dependency-level trimming — `verdict: do it, but it won't fix #926` (low impact / very-low effort / ~zero risk)
The only invariant-safe, today-mergeable change in the set. Swap `highlight.js` → `highlight.js/lib/common` (4 import lines: `Viewer.tsx:3`, `InlineMarkdown.tsx:3`, `blocks/CodeBlock.tsx:2`, `review-editor/HighlightedCode.tsx:2`) drops 156 languages (~370 KB minified). Honest impact is sub-perceptual in isolation (~1.8% of JS), but it removes real bytes inside the single-file model with no architectural risk. The natural first commit of a "shrink the bundle" campaign — not a solution on its own.

### 2. Multi-asset + cached serving with a stable origin — `verdict: the real fix, but a re-architecture` (high impact / large effort / medium-high risk)
The only path that attacks **both** halves of the root cause. Drop `viteSingleFile`/`inlineDynamicImports` for the local-server target, build the plan editor as a normal chunked Vite bundle (the **portal already does this with the same `App.tsx`** — verified), embed the `dist/` tree into the binary via **`Bun.embeddedFiles`** (verified real), serve `/assets/*` content-hashed files with `Cache-Control: public, max-age=31536000, immutable` + `ETag` ahead of the SPA fallback (`packages/server/index.ts:577`), and `React.lazy()` Mermaid, xterm, and CodeMirror so they become real deferred chunks. Code-splitting alone drops a diagram-free plan-approve load from ~20.3 MB toward **~6–9 MB core**; a stable origin + immutable assets lets the **V8 bytecode cache survive across sessions** → "5s every time" becomes "~2–3s once, then sub-second." **Killer dependency: the stable origin.** Without solving port churn, caching buys nothing and only the cold-load win remains.

### 3. Persistent server + tab reuse across plan iterations — `verdict: most targeted at "every time," but invasive` (high repeat-load impact / large effort / high risk)
Keep one long-lived server on a stable per-project port and push new plan data into the **already-warm tab via the existing SSE channel** instead of `openBrowser()`-ing a new origin. Iterations 2..N become near-instant (no re-parse). Requires decoupling server lifetime from the per-decision process (today: start → `waitForDecision` → `server.stop` → exit), collision-managed stable ports, and three-runtime replication. First open still pays full cost — **pairs with #2, doesn't replace it.** A lighter alternative to the broker in #2's Phase 2.

### 4. Lazy-load heavy panels (terminal + editor) off the plan path — `verdict: only valuable inside #2` (modest impact / large effort if standalone)
Directionally correct — xterm + CodeMirror are eager dead weight on plan review (`App.tsx:8,119-121`, zero `React.lazy`) — but **structurally blocked alone**: `inlineDynamicImports:true` folds any `React.lazy` back into the one chunk, so it still parses up front. It also only removes the ~1.5–3 MB terminal/editor slice, leaving the dominant ~13 MB of Mermaid+Shiki untouched. Worth doing as a **free compounding win** once #2 makes chunks real.

### 5. Per-surface plan-vs-annotate bundle split — `verdict: NO-GO` (negligible impact / large effort / high risk)
Dead-end. The only truly annotate-exclusive code is the xterm terminal (~400–500 KB minified); `MarkdownEditor` is **not** removable (plan direct-edit #928 uses it; `App.tsx:1433` doesn't gate on `!annotateMode`). Saves ~0.1s while **adding a third ~20 MB embedded bundle (+57% binary)**, a new build entry, and multiplying the build-order staleness trap across three runtimes. Worst ROI in the set.

### 6. Pure caching/warm tricks on the current random-port model — `verdict: NO-GO as stated`
- Cache-Control/ETag on a random port buys nothing locally (new origin every run); only helps remote fixed-port 19432.
- Service workers are origin-scoped → a fresh-port origin gets an empty-cache SW on its only paint → zero first-paint benefit.
- Bun/V8 startup snapshots apply to the **Bun runtime, not the user's Chrome** — category error.

All three collapse into "you must fix origin churn first" (i.e. #2/#3).

---

## Recommended path (phased)

**Phase 0 — ship now (hours, zero architectural risk):**
- `highlight.js` → `highlight.js/lib/common` (4 imports). Removes ~370 KB.
- Delete the `cp dist/index.html dist/redline.html` step in `apps/hook` build — it produces a ~20 MB byte-identical **dead** artifact that's never served.
- Add a real loading skeleton/spinner behind the `isLoading` gate (`App.tsx:3749-3752` renders a bare colored div today). Doesn't make it faster, but converts a 5s "is it broken?" blank into visible progress — the cheapest win against #926's *perceived* severity.

**Phase 1 — the load-bearing prototype (prove multi-asset + faster cold load on ONE runtime):**
- In a branch, build the plan editor multi-asset (drop `viteSingleFile`/`inlineDynamicImports` for the local-server target only — the portal config is the working proof).
- Embed `dist/` into the Bun binary via `Bun.embeddedFiles`; add an `/assets/*` route serving content-hashed files with `immutable` cache headers + `ETag`, `index.html` with `no-cache`.
- `React.lazy()` Mermaid, xterm, CodeMirror — they become real deferred chunks for free.
- **Measure** cold-load parse time for a diagram-free plan (expect ~20.3 MB → ~6–9 MB core JS) and **prove it works in the backendless portal** (chunks served as static files; graceful when `/api/*` absent). This phase delivers the faster **cold** load even with caching deferred.

**Phase 2 — kill "every time" (the harder half):**
- Pick ONE origin-stability mechanism: a small per-machine **broker on a fixed port** routing sessions by path/query token (lets immutable-asset + V8 bytecode cache survive across iterations), or fall back to **theory #3** (persistent server + tab reuse via SSE), which sidesteps origin churn by never opening a new tab.
- Validate coexistence with concurrent sessions (the EADDRINUSE problem random ports solve today) and with the share-URL/remote flow, cookies, and the portal.

**Phase 3 — replicate** the chosen embedding+serving across OpenCode (file-copy → dist tree) and Pi (readFileSync → dir); update build-order/staleness guards.

---

## No-gos (explicit)

- Per-surface plan/annotate split (adds a third 20 MB bundle for ~0.1s).
- Cache headers on the current random-port server (zero local benefit).
- Service workers under random ports (empty cache on the only paint).
- `React.lazy` around heavy panels while keeping `inlineDynamicImports:true` (Rollup folds it back — false confidence).
- CDN-hosted chunks (breaks offline / portal no-network guarantee).
- Bun/V8 snapshots to speed the browser (wrong runtime).

---

## Open questions a follow-up prototype must answer

1. **Real parse attribution** on macOS/Chrome: flame-chart the cold load — 143 Shiki `JSON.parse` vs Mermaid eager init vs xterm/CodeMirror vs React mount. The whole plan rests on Shiki+Mermaid being dominant.
2. **Does V8 reuse bytecode cache** for content-hashed `immutable` assets across separate tab loads on the same stable origin in current Chrome? The Phase-2 payoff depends entirely on this — verify with DevTools "Script Compilation" cache hits before building the broker.
3. **Can the 143 Shiki TextMate grammars be subset or lazy-loaded** independently of the single-file question? They're ~8.2 MB in **both** bundles via `@pierre/diffs`→shiki (`CodeFilePopout`, `App.tsx:87`). If only a handful of languages matter for plan code-file links, a grammar-subset or on-demand fetch could be a large, possibly invariant-safe win — its own spike.
4. **Backendless portal compatibility** with lazy chunks as static files, degrading when `/api/*` is absent — make-or-break for Phase 1.
5. **Mermaid eager cost when a plan has zero diagrams** — is the cost top-level module init/execute or just parse? If execute is gated until first `<MermaidBlock>`, `React.lazy` in multi-asset mode reclaims it fully; confirm there's no top-level side effect.
6. **Stable-port broker blast radius** — map every consumer of "unique port per session" (`share-url.ts`, remote, cookies, EADDRINUSE concurrency) before changing it.

---

## The one-paragraph recommendation

Ship Phase 0 today (hljs trim + delete the dead redline copy + a real loading skeleton) — it de-risks the *perception* of #926 immediately at zero architectural cost. Then invest the real effort in **Phase 1**: build the plan editor multi-asset (the portal proves it's possible), embed via `Bun.embeddedFiles`, serve content-hashed immutable assets, and lazy-load Mermaid/xterm/CodeMirror. That alone fixes the **cold** load. The "every time" symptom only truly dies in **Phase 2** when the origin is stabilized so the V8 bytecode cache survives — and before building that broker, profile the cold load (Q1) and prove the V8 cache reuse (Q2), because the entire Phase-2 payoff rests on those two unverified assumptions.
