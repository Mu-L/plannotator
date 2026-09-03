# Implementation spec — token hover cards, Tier 0 (search-backed)

Status: implementation scope for the approved design. Untracked by convention (do not commit).
Authoritative design artifact: `DESIGN_token-hover-cards.html` — its **Tier 0 · Search column**
and the card mock (lines 110-125, DATA at 168-208) are the contract for what the card shows and
how it behaves. Where this spec and that file disagree, that file wins.

Every file:line below was re-read against `main` at `1be15c1c` on 2026-09-02. PR #1458 may merge
first; function names are cited alongside line numbers so drifted lines stay findable.

---

## 1. What ships, and what does not

Tier 0 turns the already-wired-but-cosmetic token hover (`onTokenEnter`/`onTokenLeave` add and
remove CSS classes today) into a hover card fed by the **existing ripgrep code-nav backend** plus
three cheap server enrichments:

1. **Kind badge** — `classifyMatch` (`packages/shared/code-nav.ts:248-273`) already knows *which*
   definition regex matched and discards that; surfacing it is free.
2. **Multi-line definition preview + approximate signature** — the def line plus a short
   read-ahead, from the same file-read machinery `/api/code-nav/file` uses.
3. **Heuristic doc-comment scan** above (Python: below) the definition line, per-language for the
   five languages `DEFINITION_PATTERNS` covers, conservative — nothing over garbage.

**Non-goals, stated so review does not hunt for them:** Tier 1 (tree-sitter over the CallDiff
runtime) and Tier 2 (SCIP loader) are not built — but §3's response shape carries the
`source: 'search'` chip and nullable `signature`/`doc`/`symbolKind` fields they will later fill,
so upgrading a tier changes field *values*, never the shape. No jump-to-definition navigation
(the card's location links route into the existing References dock panel). No plan/annotate
surface work — this is code review only. No new modifier chords beyond the one Alt-click alias
(§5.5). No widening of `DEFINITION_PATTERNS` language coverage (the dumb-jump corpus mining is
the design's step 4, not this one).

---

## 2. Server: a new endpoint over extended shared logic

### 2.1 Decision: `POST /api/code-nav/hover`, not a mode flag on `/resolve` — frozen

Extending `/api/code-nav/resolve` with `mode: 'hover'` was considered and rejected:

- The response shapes genuinely differ. `/resolve` returns the full ranked location lists the
  References panel renders (`CodeNavResponse`, `packages/shared/code-nav.ts:36-43`); the hover
  card wants one enriched definition plus a capped reference sample. A mode flag means a union
  return type on an endpoint whose one existing consumer (`useCodeNav`,
  `packages/review-editor/hooks/useCodeNav.ts:22-30`) would have to be re-proven unregressed.
- `/resolve` backs Cmd+click, the interaction we must not destabilize. A separate route keeps its
  handler (`handleCodeNavResolve`, `packages/server/code-nav.ts:45-71`) byte-identical.
- The cost of a second route is ~25 lines per runtime of guard-copying, and the guards *should*
  be copied verbatim (§6) — a shared guard refactor inside this PR would widen its blast radius.

The hover pipeline reuses `/resolve`'s internals: `buildRgArgs` (`code-nav.ts:163-187`),
`parseRgJsonOutput` (`:202-242`), `rankLocations` (`:279-314`), the module-level `rgAvailable`
probe cache (`:364-380`), and the same request validation (`validateCodeNavRequest`, `:336-358`
— the hover request body IS a `CodeNavRequest`).

### 2.2 Shared pure logic — extend `packages/shared/code-nav.ts` itself

Everything decision-shaped lands in the already-vendored shared module. `code-nav` is in the
`vendor.sh` file list (`apps/pi-extension/vendor.sh:32`), so **no vendor.sh edit is needed** —
`bash apps/pi-extension/vendor.sh` (run by `typecheck`, root `package.json:37`, and the Pi build)
regenerates `apps/pi-extension/generated/code-nav.ts`.

Changes in `packages/shared/code-nav.ts`:

- **Tag the pattern tables with kinds.** `DEFINITION_PATTERNS` (`:94-133`) entries become
  `{ pattern, kind }` where `kind` is a new
  `SymbolKind = 'function' | 'method' | 'class' | 'interface' | 'type' | 'enum' | 'const' | 'variable' | 'struct' | 'trait' | 'module'`.
  `GENERIC_DEFINITION_PATTERNS` (`:135-138`) map the matched keyword to a kind. New
  `classifyMatchDetailed(snippet, symbol, language): { kind: 'definition' | 'reference'; symbolKind: SymbolKind | null }`;
  `classifyMatch` becomes a thin wrapper so `parseRgJsonOutput` (`:226`) and its tests are
  untouched.
- **`scanDocComment(lines: string[], defLineIdx: number, language?: string): string | null`** —
  pure, per-language, conservative (§2.4).
- **`buildSignature(lines, defLineIdx): { text: string; approximate: true }`** — the matched def
  line, trimmed, plus balanced-paren read-ahead of at most 2 further lines when the def line's
  parens don't balance; hard cap 300 chars. Always `approximate` in Tier 0.
- **`resolveCodeNavHover(runtime, request, cwd, changedFiles): Promise<CodeNavHoverResponse>`** —
  runs the existing search pipeline, takes `rankLocations`' top definition, reads its file via
  the runtime, slices preview/doc/signature, and assembles §3's payload. File reading rides a new
  **optional** member on `CodeNavRuntime` (`:45-51`):
  `readFile?: (path: string) => Promise<string | null>` — optional so the vendored type stays
  backward-compatible and `/resolve` callers never provide it. Missing file, unreadable file, or
  a file over 1 MB (mirror rg's own `--max-filesize 1M`, `:170-171`) degrade to
  `signature`/`doc`/`preview: null` — the card still shows the def location and refs.

### 2.3 The two runtimes — exact files touched

| File | Change |
|---|---|
| `packages/shared/code-nav.ts` | everything in §2.2 |
| `packages/shared/code-nav.test.ts` | pure-logic tests (§8) |
| `packages/server/code-nav.ts` | `readFile` on `bunCodeNavRuntime` (via `Bun.file(...).text()`); new `handleCodeNavHover(req, cwd, changedFiles)` beside `handleCodeNavResolve` (`:45-71`) |
| `packages/server/review.ts` | new route `/api/code-nav/hover` immediately after the `/api/code-nav/resolve` block (`:3053-3077`), with the **same** guard stack verbatim: `isGitButlerCommittedView()` 400, `hasCodeNavAccess` (`:3060`) 400, PR-pool cwd via `ensurePRLocalCwd()` / `resolveAgentCwdReady()` (`:3069-3071`), `extractChangedFiles(currentPatch)` (`:3075`) |
| `apps/pi-extension/server/serverReview.ts` | mirror route beside its `/api/code-nav/resolve` (`:3034`), same guards, `readFile` on `piCodeNavRuntime` via `readFileSync` |
| `apps/pi-extension/generated/code-nav.ts` | regenerated by vendor.sh — never hand-edited |
| `packages/server/code-nav-hover-endpoint.test.ts` | dual-runtime shape test (§8) |
| `CLAUDE.md` | one row in the Review Server API table |

No changes to `/api/code-nav/resolve`, `/api/code-nav/file`, or any client of either.

### 2.4 Doc-comment scan rules — conservative by construction

Per-language, keyed off the request's `language` (already supplied by `detectLanguage` via
`buildCodeNavRequest`, `packages/review-editor/utils/buildCodeNavRequest.ts:15`):

- **typescript / javascript**: a `/** … */` block ending on the line directly above the def, or a
  contiguous `//` run directly above. Strip `/**`, `*/`, leading `*`, leading `//`.
- **python**: a `"""…"""` / `'''…'''` docstring opening on the first non-blank line *below* a
  `def`/`class` def line; else a contiguous `#` run directly above. Decorator lines (`@…`)
  between comment and def are skipped, not treated as separation.
- **go**: contiguous `//` run directly above (godoc convention).
- **rust**: contiguous `///` (or `//!`) run above; `#[…]` attribute lines between doc and def are
  skipped.
- **anything else** (including `language` unset): return `null`. No generic guessing.

Global rules: one blank line between comment and def breaks the association (except through the
skip-lists above); output capped at 10 lines / 600 chars with a trailing `…`; a scan that yields
only decoration (`---`, license boilerplate detected as lines with no letters) returns `null`.
Returning nothing always beats returning garbage — the card simply omits the doc paragraph, as
the design's own Tier 0 mock does (`DESIGN_token-hover-cards.html:170-172`, `doc:''`).

---

## 3. The response shape — forward-compatible, frozen

```ts
export interface CodeNavHoverDefinition {
  filePath: string;
  line: number;
  column: number;
  confidence: 'likely' | 'possible';   // honest label; card renders "likely definition"
  symbolKind: SymbolKind | null;       // Tier 0: from the matched def-regex; Tier 1+: AST/SCIP
  signature: string | null;            // Tier 0: matched line + read-ahead; Tier 1+: exact
  signatureApproximate: boolean;       // true in Tier 0; card appends the "// matched line" cue
  doc: string | null;                  // Tier 0: heuristic scan; Tier 1+: real doc node
  preview: { startLine: number; lines: string[] } | null;  // ≤ 12 lines from the def file
  otherCandidateCount: number;         // extra ranked defs → "N candidates — ranked" label
}

export interface CodeNavHoverResponse {
  backend: 'search' | 'unavailable';
  source: 'search';                    // the card's source chip; Tier 1 'syntax', Tier 2 'index'
  symbol: string;
  definition: CodeNavHoverDefinition | null;
  references: Array<{ filePath: string; line: number; column: number; snippet: string }>; // top 5
  referenceCount: number;              // total within search caps
  capped: boolean;                     // true ⇒ card says "50+" per the design's honesty rule
  stats: { elapsedMs: number };        // the card's footer latency, e.g. "rg · 38ms"
}
```

Tiers 1/2 widen `source` and fill `symbolKind`/`signature`/`doc` with exact values; nothing else
moves. `backend: 'unavailable'` (rg missing — the cached probe, `code-nav.ts:374-391`) is a
normal 200 and the client renders **nothing**: no card, no toast, no error state.

---

## 4. Client: hook, stitching, card

All new client code lives in `packages/review-editor` (no `packages/ui` publish, no new
directories — Tailwind `@source` untouched).

### 4.1 `utils/stitchTokenIdentifier.ts` — compound-token stitching

Pierre's token transformer stamps each token span with `data-char` = its char-start offset
(`node_modules/@pierre/diffs/dist/managers/InteractionManager.js:944-957` is the consumer;
`toTokenEventBaseProps` at `:890`). Shiki can fragment a single identifier across spans, so:

`stitchTokenIdentifier(tokenElement): { symbol: string; charStart: number } | null` walks
`previousElementSibling`/`nextElementSibling` while (a) the sibling has `data-char`, (b) offsets
are adjacent (`prevStart + prevText.length === nextStart`), and (c) the concatenation still
matches `/^[A-Za-z_$][\w$]*$/`. It deliberately does **not** join across `.`/`::` — with
`--word-regexp` (`buildRgArgs`, `code-nav.ts:184`) the dotted path finds nothing; the segment is
the searchable unit. Returns `null` (⇒ no hover) for non-identifiers, pure keywords (a small
generic stoplist: `const let var function return if else for while import export from class new
type interface async await pub fn def self this`), and identifiers shorter than 2 chars. This
filter is the first-line cost control: punctuation, operators and keywords never reach the wire.

### 4.2 `hooks/useTokenHover.ts`

Modeled on `useCodeNav` (`hooks/useCodeNav.ts:12-39`) and `useCodeNavPreview`'s LRU
(`hooks/useCodeNavPreview.ts:3`, `:48-52`):

- **Debounce 350 ms** from `onTokenEnter` — the fetch fires only after dwell, so fast mouse
  travel across a diff spawns zero requests.
- **Single in-flight, abort-superseded** — same `AbortController` ref pattern as `useCodeNav`.
- **LRU cache, 30 entries**, keyed `${symbol}|${filePath}|${side}`; cleared whenever the active
  diff snapshot changes (the App already tracks `snapshotId`) so a refresh never serves stale
  positions.
- **Leave with grace**: `onTokenLeave` starts a ~250 ms close timer; pointer entering the card
  cancels it; leaving the card restarts it (the design mock's own scheme,
  `DESIGN_token-hover-cards.html:251-259`).
- **Cancel on scroll**: a capture-phase `scroll`/`wheel` listener (active only while a card is
  open or pending) closes the card and aborts the pending fetch — the anchor rect is stale the
  moment the pane scrolls.
- **Render threshold**: a response renders only when it has a definition or ≥ 2 references;
  otherwise nothing. `backend: 'unavailable'`, fetch failure, abort, and timeout all render
  nothing, silently.

### 4.3 `components/TokenHoverCard.tsx`

One instance, owned by the review App and portaled to `document.body` (it must escape the
Dockview panel's overflow and z-index stack). Anchored at `tokenElement.getBoundingClientRect()`
— below the token, flipped above when the viewport bottom would clip it, clamped horizontally
(the mock's math, `DESIGN_token-hover-cards.html:243-248`). Contents per the design card
(`:110-125`): symbol name, kind badge (hidden when `symbolKind` null), **source chip `search`**,
signature block with the `// matched line` cue when `signatureApproximate`, doc paragraph (hidden
when null), "Defined at <path:line>" link with the honest confidence label (`likely definition` /
`N candidates — ranked`), reference list capped at 5 with "… N more in the References panel", the
`50+` capped note, and the footer (`⌘click` / `⌥click` hints + `rg · Nms` latency). Location
links route into the existing References flow: they call the same `handleCodeNavRequest`
(`packages/review-editor/App.tsx:1051-1079`) that Cmd+click uses, which opens/focuses the
`REVIEW_CODE_NAV_PANEL_ID` dock panel. The card never claims certainty Tier 0 lacks.

### 4.4 Wiring — exact sites

- **`components/DiffViewer.tsx`** — two new optional props beside `onCodeNavRequest` (`:224`):
  `onTokenHoverEnter?: (request: CodeNavRequest, tokenElement: HTMLElement) => void` and
  `onTokenHoverLeave?: () => void`. `handleTokenEnter` (`:720-725`) additionally calls
  `onTokenHoverEnter(buildCodeNavRequest(stitched…), props.tokenElement)` when the prop is
  present and stitching yields a symbol; `handleTokenLeave` (`:727-730`) calls
  `onTokenHoverLeave`. The `onToken*` passthrough into Pierre options (`:122-125`) and the memo
  comparison (`:152-154`) already flow these through unchanged.
- **`components/AllFilesCodeView.tsx`** — same pair beside `onCodeNavRequest` (`:254`,
  destructured `:580`); `handleTokenEnter` (`:1979-1985`) / `handleTokenLeave` (`:1987-1989`)
  extended identically, with file identity from `itemIdToFilePath` exactly as `handleTokenClick`
  does (`:1969-1977`). The guide chain inherits nothing (§6).
- **`App.tsx`** — mounts `useTokenHover` + one `<TokenHoverCard>`; passes the two handlers to
  both views **only when** `canUseLiveWorkspaceActions` (`:1369-1370`) **and** the setting (§4.5)
  is on — the same conditional-prop gate as `onCodeNavRequest` (`:3384`). The existing
  gate-flip effect (`:1375-1379`) additionally closes any open hover card.
- **Cmd+click untouched; Alt+click added.** `handleTokenClick` in both views keeps its
  meta/ctrl branch byte-identical (`DiffViewer.tsx:712-718`, `AllFilesCodeView.tsx:1969-1977`)
  and gains `event.altKey` as an alias into the same References-panel path, per the design
  footer (`DESIGN_token-hover-cards.html:124`). A plain click on a token still falls through to
  the annotation toolbar host (`DiffViewer.tsx:717`) — the card renders outside the token and
  intercepts no token clicks.

### 4.5 Settings — one row, default on, cookie-only

New registry entry `tokenHoverCards` in `packages/ui/config/settings.ts` (registry contract
`SettingDef`, `:92-100`): `defaultValue: true`, cookie `plannotator-token-hover-cards` with the
standard boolean codec (pattern: `conventionalComments`, `:529-543`), **no `serverKey`** —
deliberately cookie-only, because a presentational per-browser preference does not justify
touching both runtimes' `POST /api/config` allowlists, and precedent exists
(`reviewPanelViewLastUsed` is cookie-only by design, per CLAUDE.md). One toggle row in the
review section of `packages/ui/components/Settings.tsx` ("Token hover cards" — read via
`useConfigValue`, written via `configStore.set`, the pattern at `Settings.tsx:707`, `:744-745`).
Off ⇒ App passes no hover handlers ⇒ zero listeners, zero fetches, zero DOM.

---

## 5. Gates and exclusions — verified mechanisms

| Surface / condition | Mechanism | Result |
|---|---|---|
| GitButler committed views | client: `canUseLiveWorkspaceActions` (`App.tsx:1369-1370`) withholds the handler props; server: `isGitButlerCommittedView()` guard copied from `/resolve` (`review.ts:3054-3059`) | no hover, no card |
| No local checkout (PR mode without `--local`, piped patch) | server `hasCodeNavAccess` / `ensurePRLocalCwd` guards (`review.ts:3060-3074`) return 400; the hook renders nothing on non-OK | no card, no toast — unlike Cmd+click, hover must not nag (`App.tsx:1052-1057`'s toast stays click-only) |
| rg not installed | `backend: 'unavailable'` from the cached probe (`code-nav.ts:374-391`) | 200, no card, no error |
| guides.show / portable / read-only | **by construction**: token wiring activates only when the hover props are provided; `ReadOnlyDiffRenderer` (`apps/guides-show/viewer/ReadOnlyDiffRenderer.tsx:55`) passes neither `onCodeNavRequest` nor the new props (verified: zero matches in `apps/guides-show/` and `packages/guide-viewer/`), and no server exists behind the portable file anyway | feature absent; portable bundle unchanged |
| Setting off | no handler props (§4.5) | feature absent |

---

## 6. Costs and risks

- **rg spawn rate.** The debounce is dwell-gated: sweeping the pointer across 50 tokens spawns
  nothing; resting on one token spawns at most one rg per 350 ms dwell, single-in-flight. The
  identifier/keyword filter (§4.1) removes most of the remaining volume. Residual: the server
  cannot cancel a spawned rg when the client aborts the fetch — the process runs to completion or
  its timeout. Bounded by client discipline (one in flight) at worst-case one orphaned rg per
  dwell. If real-world use shows pile-ups, `packages/shared/single-flight.ts` (already vendored)
  can coalesce identical concurrent hover keys server-side — deliberately **not** built now.
- **5 s timeout interplay.** `resolveCodeNav` hardcodes `timeoutMs: 5000` (`code-nav.ts:395-398`).
  A 5 s hover answer is useless; `resolveCodeNavHover` passes 3000 through an additive options
  parameter, and a timeout renders nothing. `/resolve` keeps its 5000.
- **Large repos.** Existing caps bound the search: `--max-count 50` per file, `--max-filesize 1M`
  (`buildRgArgs`, `code-nav.ts:167-172`), `PARSE_CAP` 500 (`:200`), rank cap 50 (`:286`). The
  hover adds one bounded file read. Worst case on a cold monorepo is the same latency Cmd+click
  already exhibits; the card just doesn't appear until the answer lands, and the footer prints
  the honest elapsed time.
- **DOM cost: already paid.** `useTokenTransformer: true` is set globally in the worker options
  (`packages/review-editor/workerPool.tsx:33`) and per-component
  (`DiffViewer.tsx:122`, `AllFilesCodeView.tsx:2527`) — token spans and `data-char` attributes
  exist in every review today. Tier 0 adds no render-path weight.
- **Pierre API caveat.** The `onToken*` hooks ride a passthrough that exists because "Pierre's
  renderer-options builder drops onToken* before it evaluates" (comment at `DiffViewer.tsx:118`,
  `AllFilesCodeView.tsx:2524`) — the surface is effectively experimental in our pinned
  `@pierre/diffs` 1.3.2. Risk accepted: the pin is ours, an upgrade already has to re-verify
  Cmd+click, and the hover degrades to nothing if the events stop firing.

---

## 7. Tests — minimal high-value set (per CLAUDE.md Testing Rules)

Each guards a nameable regression; nothing snapshots prose.

**Pure (`packages/shared/code-nav.test.ts`, extending the existing file):**
- `classifyMatchDetailed` kind extraction: one case per kind class per language table entry —
  failure caught: a pattern-table edit silently reclassifying kinds.
- `scanDocComment`: JSDoc block, `//` run, Python docstring-below + decorator skip, Go `//`,
  Rust `///` + `#[attr]` skip, blank-line separation returns null, unknown language returns
  null, cap + boilerplate rejection — failure caught: the scan returning garbage, the thing §2.4
  exists to prevent.
- `buildSignature`: balanced single line, 2-line read-ahead stop, cap — failure caught: unbounded
  read-ahead.
- `resolveCodeNavHover` with a stub runtime: `unavailable` passthrough, missing `readFile`
  degrades fields to null but keeps the definition, `capped`/`referenceCount` honesty.

**Client pure/DOM (`packages/review-editor`):**
- `stitchTokenIdentifier`: fragmented identifier joins, non-adjacent offsets don't, dots don't,
  keyword stoplist returns null — failure caught: hover firing rg for `const`.
- `useTokenHover` (fake timers): no fetch before 350 ms; supersession aborts; leave-then-
  hover-into-card keeps it open; leave from card closes; `unavailable` renders nothing —
  failure caught: the spawn-rate and grace contracts, the two behaviors most likely to be
  "simplified" away.
- One `TokenHoverCard` mount test: renders nothing without a definition and < 2 refs — failure
  caught: an empty card flashing on every hover.

**Dual-runtime endpoint (`packages/server/code-nav-hover-endpoint.test.ts`,** pattern:
`packages/server/generated-files-endpoint.test.ts`): boot both servers against a temp repo,
POST a hover request, assert the §3 shape including `source: 'search'`, and assert the 400 gate
without local access — failure caught: the runtimes drifting, the repo's standing two-runtime
hazard.

Not written, on purpose: card CSS/positioning tests (assert nothing that can regress
meaningfully in jsdom), settings-row round-trips (any string round-trips), and re-tests of
`/resolve` internals already covered by `code-nav.test.ts`.

---

## 8. PR breakdown — two stages, frozen

**PR1 — server (`~450` LOC incl. tests): shared enrichments + `/api/code-nav/hover` in both
runtimes.** Files: §2.3's table. Nothing user-visible ships; the endpoint is dark until PR2.
Review hunts: (1) doc-scan garbage cases — feed it real ugly headers; (2) guard parity — diff the
new route's guard stack against `/resolve`'s (`review.ts:3053-3077`) token by token, both
runtimes; (3) the Pi mirror — hand-written, the historical drift site; (4) `CodeNavRuntime`
optional-member compatibility with the regenerated vendored copy.

**PR2 — client (`~500` LOC incl. tests): stitch + hook + card + wiring + setting.** Files: §4.
Review hunts: (1) listener hygiene — enter/leave fire per token at high frequency; nothing may
allocate listeners per token (one document-level scroll listener, active only while open); (2)
Cmd+click byte-parity in both views' `handleTokenClick`; (3) zero-footprint when the setting is
off or props absent — including that the guides.show viewer bundle stays byte-identical; (4)
card portal z-index over Dockview panels and the viewport flip.

Not one PR: the server half is provable by tests alone and reviewable against `/resolve` line by
line, while the client half is an interaction surface that needs hands-on review in the browser;
fusing them makes the reviewer do both jobs at once across two runtimes and a UI. Not three: the
stitch/hook/card pieces are meaningless apart.

---

## 9. Open questions for the maintainer

1. **Modifier-free hover vs modifier-gated — the big one.** The design mock is modifier-free and
   this spec follows it: 350 ms dwell + identifier filter + the settings toggle are the
   mitigations. The tradeoff: modifier-free is discoverable and matches every IDE, but puts a
   subprocess spawn behind an idle gesture; modifier-gated (card only while ⌘ held) costs
   discoverability and collides with ⌘-hover already meaning "click will navigate"
   (`pn-token-nav`, `DiffViewer.tsx:722-724`). **Recommendation: modifier-free, as designed.**
   If vetoed, the change is confined to one predicate in `useTokenHover`.
2. **The design footer's `⌘click jump`.** The mock's footer redefines ⌘click as jump-to-def with
   ⌥click for the References panel. Today ⌘click opens the References panel. This spec keeps
   ⌘click unchanged and adds ⌥click as an alias (§4.4) — repurposing ⌘click to a true
   jump-to-definition is real new navigation work and a silent behavior change for existing
   users. Confirm the footer copy should read "⌘/⌥click references panel" for Tier 0, or
   schedule the jump as its own follow-up.
3. **Python doc precedence** when both a `#` run above and a docstring below exist: this spec
   says docstring wins (it is the authored doc). Cheap to flip in review.

---

## 10. Post-mock copy rulings (maintainer, final)

The first mock leaked engineering vocabulary into the card. These rulings supersede §4.3's
contents list where they conflict:

1. **No source chip.** Tier 0 has exactly one source; a `search` badge tells the user
   nothing. Reintroduce a source indicator only if and when a second tier actually ships,
   and reconsider even then.
2. **No rank/confidence vocabulary.** Never render "ranked", "likely definition", or
   candidate counts as labels. When the search yields ONE definition, the line is simply
   "Defined at path:line". When it yields several, SHOW them: the top match first, the
   runner-up on a second line ("or possibly path:line"), capped at two; more than two
   candidates means the answer is too weak for a card line and the extras belong in the
   References panel. Uncertainty is expressed by showing the alternatives, not by
   describing the algorithm.
3. **No latency readout.** "rg · 38ms" / "cache · 0ms" is debug telemetry. If wanted for
   development, put it behind a debug flag; it never ships in the default card.
4. **One footer hint, not an alias catalog.** The card teaches exactly one thing:
   "Click a location to jump. Cmd-click a token for the full References panel." The
   Alt-click alias may exist in code but is not advertised on the card.
5. **Em-dash rule applies** to every string the card renders, same as the decision control.
