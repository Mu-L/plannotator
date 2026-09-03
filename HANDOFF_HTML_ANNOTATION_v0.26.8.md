# Handoff: Raw-HTML Annotation Architecture (v0.26.8)

**Audience:** the commercial Workspaces team, which has its own annotate-HTML features.
**Purpose:** Plannotator v0.26.8 replaced DOM-mutation highlighting with an overlay-projection model. This is now the reference implementation. This document explains what shipped, why it is better, exactly where everything lives, and how to adopt it.

All paths are relative to the Plannotator repo root (`/Users/ramos/plannotator/plannotator`), at tag `v0.26.8` (commit `2fff8756`). Line numbers reference that commit.

**The one rule that governs everything else:** do not reimplement this UI. `packages/ui/README.md:110` records that a prior from-scratch rewrite broke the app and was reverted. The supported path is to consume `HtmlViewer` from `@plannotator/ui` and plug your backend in through `configurePlannotatorUI()` seams (`packages/ui/README.md:11-33`). If a seam you need does not exist, add one to `@plannotator/ui`; do not fork the viewer.

---

## 1. Evaluation: what shipped and why it is the better model

### The problem with the old model (and probably yours)

The previous implementation, like most HTML annotation tools, wrote highlight markup directly into the annotated page's DOM (wrapping selected ranges in `<mark>` elements). That approach has two structural failure modes that no amount of patching fixes:

1. **Partial highlights.** A selection spanning multiple block elements cannot be wrapped in one `<mark>`, so multi-paragraph selections rendered only their first fragment highlighted.
2. **Layout breakage.** Inserting elements into someone else's DOM changes that DOM. Pages styled with child selectors, `:nth-child`, flex/grid item counts, or `white-space`-sensitive layouts visibly broke when a `<mark>` appeared inside them.

Both bugs share one root cause: mutating a document you do not own. v0.26.8 removes the cause. **Nothing is ever written into the annotated page's DOM.** The page renders byte-for-byte as authored; annotations exist only as data plus a disposable visual projection painted above the page.

### The new model in one paragraph

Every annotation stores a **durable anchor**: a verified-unique CSS selector, tag name, a normalized text snapshot, and a normalized click point inside the element's rect (`HtmlElementAnchor`, `packages/ui/types.ts:96`). Markers and highlights are **projections**: on every relevant DOM change, scroll, resize, animation settle, or font load, the anchor is re-resolved against the current document and its marker/highlight rectangles are recomputed and repainted into a fixed, pointer-transparent, shadow-rooted overlay that sits outside `<body>`. Anchors are data; markers are pixels. Pixels are never trusted or persisted.

### Verdict

This is the strongest annotation surface Plannotator has shipped, and the architecture is the part worth copying, not any individual widget. Specifically:

**Strengths (each verified by tests listed in section 9):**

- **Layout neutrality is structural, not best-effort.** The overlay host is `position:fixed; inset:0; pointer-events:none; z-index:2147483647` appended to `documentElement`, with painting inside a shadow root (`bridge-script.ts:1201-1243`). The page cannot observe it through CSS selectors and the viewer cannot break page layout, by construction.
- **Anchors fail closed.** If a unique selector cannot be built (depth cap 40, ambiguous paths, text-less elements without stable identity), the anchor is `null` and the annotation degrades to text-search restore rather than guessing (`bridge-script.ts:2331-2412`). A marker is omitted when its target is gone, clipped away, or hidden; it never floats over unrelated content (`bridge-script.ts:2069-2070`).
- **Re-render resilience.** Anchors survive full page re-renders, responsive reflow, zoom, and container scrolling because projection is recomputed from the live DOM, not cached pixels. This is what makes the model viable for annotating app-like HTML, not just static exports.
- **Performance discipline under mutation-heavy pages.** Reconciles are rAF-coalesced (`bridge-script.ts:1128-1153`); mutations that touch only the overlay are filtered out and zero-work passes are skipped (`bridge-script.ts:4052-4078`); dead-target re-search is gated by a DOM generation counter, exponential backoff (300ms to 5s), and a 2-search-per-pass budget (`bridge-script.ts:1488-1546`); offscreen targets are culled with a 64px margin (`bridge-script.ts:1701-1710`); highlight rects are capped at 48 per range with reads and writes batched into separate phases (`bridge-script.ts:1169`, `:1810-1949`).
- **A real trust boundary.** The iframe is `sandbox="allow-scripts"` only (`HtmlViewer.tsx:639`). Every message from the bridge is parsed through a validating DTO layer with length caps on every field before touching React state (`useHtmlAnnotation.ts:109-268`). A hostile HTML file cannot inject unbounded strings, forge target keys, or smuggle markdown structure into agent feedback (newline-collapsing on labels, asserted at `packages/ui/utils/parser.test.ts:1785`).
- **Numbering parity with agent feedback.** The number on a bubble equals the `## N.` section number in the exported feedback, maintained by a parent-authoritative sync (`annotationNumbering.ts:29`, contract documented at `:11-28`). "See comment 3" means the same thing on screen and in the agent session.
- **Test depth.** About 8,700 lines of tests cover this surface (section 9), including adversarial cases: forged bridge messages, hostile labels, clip containers, fixed-position containing blocks, generation-gated backoff, batch restores, and print. The release itself went through three adversarial review rounds plus a 25-item QA gate with independent verification.

**Honest weaknesses (do not inherit these silently; decide about each):**

- **Print is highlights-only.** A fixed overlay cannot paginate, so printing uses a best-effort absolute-coordinate layer for highlight stripes; placed markers and element-only targets (SVG anchors, multi-select extras) have no print representation (`bridge-script.ts:4138-4148`, `CLAUDE.md:570`).
- **Share links drop anchors.** Shared URLs intentionally carry neither `htmlAnchor` nor `htmlAdditionalTargets`; restore on the receiving end is text-search based (`CLAUDE.md:628`, contract test `packages/ui/utils/sharing.multiTarget.test.ts`). Anchor-carrying share payloads are future work.
- **`postMessage` uses `targetOrigin: "*"` on both sides.** This is sound here because a `srcdoc` sandbox has an opaque origin and both listeners verify `e.source` identity (`bridge-script.ts:221,404`; `HtmlViewer.tsx:348`; `useHtmlAnnotation.ts:408`). **If Workspaces hosts the annotated content on a real origin (a served iframe, a proxy), this is not sufficient. You must add strict `targetOrigin` and origin checks.** Do not copy the `"*"` pattern outside a `srcdoc` sandbox.
- **The bridge is a 4,271-line string constant** with a hard authoring constraint (section 7) enforced only structurally, not by a lint rule.
- **Deliberate non-features:** `opacity:0` targets still project (only `visibility`/`display` hide them, `bridge-script.ts:1732-1746`); global comments consume an export number but no bubble, so on-page numbering can have gaps (`annotationNumbering.ts:23-27`).

---

## 2. File inventory (the entire surface)

Directory: `packages/ui/components/html-viewer/`

| File | Lines | Role |
|---|---|---|
| `bridge-script.ts` | 4,271 | The in-iframe agent as a string constant: `ANNOTATION_HIGHLIGHT_CSS` (`:17-211`) and `BRIDGE_SCRIPT` (`:213-4271`). Selection, pinpoint, anchoring, overlay projection, vim, print, message protocol. |
| `srcdoc.ts` | 145 | Pure string builder: theme-token namespacing, CSP meta neutralization, `<head>` injection. No DOM, fully unit-testable. |
| `useHtmlAnnotation.ts` | 824 | Parent-side trust boundary and React state: bridge message validation, composer/toolbar state, multi-target drafts, annotation creation, restore posting. |
| `HtmlViewer.tsx` | 763 | The React component: builds srcdoc, renders the sandboxed iframe (`:636-659`), owns theme/vim/input-method/numbering postMessage effects, portals the toolbar and composer. |
| `annotationNumbering.ts` | 37 | Parent-authoritative bubble numbering matching export order; `MAX_SYNC_ANNOTATIONS = 512` (`:9`). |
| `composerYield.ts` | 51 | Pure state machine: the composer fades and yields clicks while shift-click multi-select is in progress. |
| `index.ts` | 1 | Re-exports `HtmlViewer`, `HtmlViewerProps`. |

Supporting files outside the directory:

- `packages/ui/types.ts:96` `HtmlElementAnchor`, `:118` `HtmlAnnotationTarget`, plus `Annotation.htmlAnchor` / `Annotation.htmlAdditionalTargets`.
- `packages/ui/utils/parser.ts:1106-1125` `additionalTargetsExportBlock` (multi-target feedback rendering), call sites `:1218`, `:1322`.
- `packages/ui/utils/htmlChrome.ts` (73 lines), `packages/ui/utils/inputMethod.ts` (90), `packages/ui/utils/preferenceTtl.ts` (15): minimal-by-default session chrome with 7-day preference decay.
- `packages/editor/App.tsx`: chrome restore effect `:1623-1648`, save effect `:1655-1669`, re-stamp on annotation activity `:3324-3338`.

---

## 3. Injection pipeline and the security boundary

How raw HTML becomes an annotatable page:

1. `HtmlViewer.tsx:234-242` memoizes the srcdoc: `injectIntoHead(rawHtml, buildSrcdocInjection({ tokens, isLight, hostTheme, diffActive }))`.
2. `srcdoc.ts:102-121` builds one injected block: `<style>` (namespaced theme tokens + `ANNOTATION_HIGHLIGHT_CSS`) plus `<script>` (the whole `BRIDGE_SCRIPT`). No external fetches; everything is inline (`bridge-script.ts:9`).
3. `srcdoc.ts:138-145` `injectIntoHead` first calls `neutralizeMetaCsp` (`:123-135`), which replaces any `<meta http-equiv="Content-Security-Policy">` with a comment. Rationale: the page's own CSP was written for standalone hosting and blocks the inline bridge; the iframe `sandbox` attribute is the actual security boundary here, so the document-authored CSP is redundant defense that breaks the product (this was a real user-reported bug, fixed in `c4fc79f0` / PR #1259). The file on disk is untouched.
4. The iframe renders with `sandbox="allow-scripts"` and **no** `allow-same-origin` (`HtmlViewer.tsx:639`). The page runs with an opaque origin: no cookies, no storage, no same-origin fetch against the host.
5. Handshake: the bridge posts `ready` on DOMContentLoaded (`bridge-script.ts:4244`); the parent gates every downstream effect (restore, numbering, theme, vim, input method) on having seen it (`HtmlViewer.tsx:346-393`, effects at `:434-529`).

**Theme neutrality contract:** the viewer's own CSS variables are all namespaced `--pn-*` (`srcdoc.ts:49,78-88`), so the viewer writes nothing into the document's variable namespace unless the document explicitly opts into host theming. Enforced by string-level assertions in `srcdoc.test.ts:88-104`.

**Message authentication:** parent verifies `e.source === iframe.contentWindow` (`HtmlViewer.tsx:348`, `useHtmlAnnotation.ts:408`); bridge verifies `e.source === parent` (`bridge-script.ts:221,404`). See the section 1 warning before reusing this in a real-origin context.

---

## 4. The anchor model (the part most worth stealing)

### Building an anchor (`bridge-script.ts:2267-2459`)

A semantic ladder, each rung verified against the live document with a real `querySelectorAll` before acceptance:

1. `#id` if uniquely selecting.
2. `tag[identity-attr="value"]` over `ANCHOR_IDENTITY_ATTRS` (data-testid and friends, `:2273`), values capped at 240 chars, no newlines.
3. Up to 2 "meaningful" classes (utility/generated class names filtered by `isLikelyGeneratedClass`, `:2293`).
4. Full ancestor path with `tag:nth-of-type(n)` segments, depth-capped at `MAX_ANCHOR_PATH_DEPTH = 40` (`:2338`).
5. Failure returns `null`. **Never guess.**

The anchor also stores:

- A whitespace-collapsed, 180-char text snapshot (`anchorTextSnapshot`, `:2275`). Weak selectors (path-based) must still match this text at resolve time or resolution fails closed (`resolveAnchorElement`, `:2414-2434`).
- A normalized click point, `{x, y}` in 0..1 of the element's rect (`normalizePointInElement`, `:2450-2459`). This is why a bubble sits where the user clicked, not at a corner, and reprojects correctly when the element moves or resizes.
- Text-less elements (icons, svg paths) require a stable identity attribute or get no anchor at all (`:2377-2412`).

### Resolving and projecting

`restoreAnnotation` (`:1420-1478`) walks a restore ladder: SVG anchor as element target; resolved anchor plus anchor-scoped text search; document-wide text search; resolved element as last resort. Additional multi-select anchors restore anchor-only, capped at 16.

Projection (`renderAnnotationOverlay` and `placeMarkers`, `:2036-2230`):

- Marker point = anchor point reprojected into the element's current rect, clamped 29px from viewport edges; association with the target is tested against the unclamped point with 16px tolerance (`markerViewportPoint`, `:1755-1775`).
- Coincident markers (same rounded pixel) spread horizontally by 12.5px steps, sorted by `(number, id)` for stable order (`:2036-2093`).
- Clipping: a 200-deep ancestor walk computes effective clip bounds, correctly skipping past `overflow` ancestors when the target is fixed-positioned (`clipBoundsFor`, `:1644-1694`). Fully clipped or `visibility`-hidden targets project nothing.
- Highlight rects: per-line client rects, container rects dropped, capped at 48 with the true last rect read by index (`:1782-1837`), pooled and flushed in a single write phase (`:1906-1949`).

### The reconcile loop

One rAF-coalesced pass (`schedulePinpointReconcile`, `:1128-1153`) triggered by: capture-phase scroll, resize, a MutationObserver on `documentElement` (overlay-own mutations filtered by node identity, `:4052-4101`), animation/transition settle events (`:4109`), `document.fonts.ready` and subframe loads (`:4122-4136`), and a ResizeObserver on `body` (`:4236`). Real mutations bump `domGeneration`; a dead target is only re-searched when the generation changed since its last failure, its backoff window elapsed, and the per-pass budget (2) allows it (`:1488-1546`). Budget-starved passes reschedule themselves; user-initiated actions (scroll-to, print) run with an infinite budget (`:2225,2249,4182`).

---

## 5. Shift-click multi-select (one comment, many elements)

Data model: the primary target lives in `Annotation.htmlAnchor` + `originalText`; up to 16 extra elements ride in `Annotation.htmlAdditionalTargets` as `{label?, text, anchor?}` (`packages/ui/types.ts:118`).

Flow:

1. A pinpoint selection opens the composer and arms multi-select in the bridge (`arm-multi-select`, `useHtmlAnnotation.ts:443-475`; armed state only ever set by the parent, `bridge-script.ts:542-554`).
2. Shift-click toggles targets: dedup by element identity then anchor equality, live outline boxes, `multi-target-added` / `multi-target-removed` round trips (`bridge-script.ts:2535-2624`).
3. Removing the primary promotes the next target; removing the last cancels the draft; a forged removal message triggers an idempotent resync instead of state corruption (`useHtmlAnnotation.ts:343-373`).
4. While shift is held near the composer, the composer fades and yields pointer events so you can click "through" it (`composerYield.ts`, wired at `HtmlViewer.tsx:252-334`).
5. Submit writes one annotation; every target gets a bubble with the same number.

Export: `additionalTargetsExportBlock` (`parser.ts:1106-1125`) appends `**Also applies to N more element(s):**` with `- [Label] "excerpt"` lines (labels whitespace-collapsed, excerpts clipped at 120 chars). Single-target output is byte-identical to the pre-feature format (asserted at `parser.test.ts:1809`).

---

## 6. Session chrome: minimal by default, preferences that decay

New in v0.26.8 and directly relevant to any product decision about "what should the annotation surface look like on open":

- An HTML session opens with just the page: pinpoint input, tools hidden, sidebar and annotations drawer closed (`DEFAULT_HTML_CHROME_STATE`, `packages/ui/utils/htmlChrome.ts:32`; `DEFAULT_HTML_METHOD = 'pinpoint'`, `packages/ui/utils/inputMethod.ts:12`).
- User changes persist, but with a 7-day TTL (`packages/ui/utils/preferenceTtl.ts:9`). A preference untouched for a week silently reverts to the defaults; annotating re-stamps the clock (`packages/editor/App.tsx:3324-3338`). Legacy untimestamped records count as expired.
- Rationale: a mode someone tried once months ago should never be a permanent surprise, while active users keep their setup. Markdown-surface preferences are deliberately exempt from the TTL (`inputMethod.ts:39-51`).
- Wiring pattern worth copying: the restore effect sets a skip-flag so the save effect never writes stale pre-restore state back to the cookie (`App.tsx:1623-1669`, race asserted by `packages/editor/App.htmlHideTools.test.tsx:188`).

---

## 7. The bridge authoring constraint (read before editing `bridge-script.ts`)

`BRIDGE_SCRIPT` is one backtick-delimited template literal spanning `bridge-script.ts:213-4271`. Inside its body:

- **No backtick characters.** A stray backtick terminates the constant.
- **No `${` sequences.** They would interpolate at module load, silently corrupting the emitted script.
- **All backslashes doubled** so the emitted JS sees a single backslash (examples: `:965`, `:989`, `:1191`, `:2276`, `:2290`).

There is currently **no lint rule enforcing this**; enforcement is structural (TypeScript compile errors or silent interpolation) plus string assertions in `srcdoc.test.ts:88-104`. If Workspaces adopts the bridge, adding a CI grep for `` ` `` and `${` over the literal body is a cheap, worthwhile guard that we have not added yet.

Also note `window.__plannotatorBridgeInternals` (`bridge-script.ts:4252-4270`): a test-only introspection global, justified because it derives nothing the same-realm page could not already compute.

---

## 8. Message protocol reference

Bridge to parent (all validated by `parseBridgeMessage`, `useHtmlAnnotation.ts:206-268`, before touching state):

| Message | Meaning |
|---|---|
| `ready` | Bridge booted; parent may start posting. |
| `resize` | Content height for iframe sizing. |
| `selection` / `selection-clear` / `selection-rect` | Text or pinpoint selection lifecycle. |
| `mark-applied` | A `find-and-mark` restore resolved. |
| `mark-click` | User clicked a bubble or committed highlight (id capped at 256 chars). |
| `multi-target-added` / `multi-target-removed` | Shift-click target toggles. |
| `pointer` | Relayed pointer position for composer yield. |
| `keytype`, `vim-state`, `vim-help`, `vim-copy`, `vim-command` | Vim surface. |

Parent to bridge: `theme`, `create-mark`, `find-and-mark`, `remove-mark`, `clear-marks`, `sync-annotations`, `cancel-selection`, `arm-multi-select`, `remove-target`, `flash-target`, `scroll-to`, `focus-mark`, `set-input-method`, `set-vim-mode`, `set-vim-help`, `focus-vim`. Dispatch table at `bridge-script.ts:404-620`.

---

## 9. Test inventory (how we know it works)

| Test file | What it locks down |
|---|---|
| `packages/ui/components/html-viewer/srcdoc.test.ts` (3,590 lines) | Rendering neutrality, CSP-meta removal variants, and the full in-DOM bridge behavior suite: anchoring ladder, fail-closed cases, marker projection/omission/clamping/spread, clip and visibility gates, generation-gated backoff and budget, viewport cull, 48-rect cap, batch restore in one pass, zero-work observer gate, print layer, click-to-select, multi-select lifecycle. |
| `packages/ui/components/html-viewer/htmlPinpointProtocol.test.tsx` (879) | The parent trust boundary: DTO validation with hostile inputs (oversized selectors, forged keys, newline labels), composer flows, promotion, caps, forged-removal resync. |
| `packages/ui/components/html-viewer/annotationNumbering.test.ts` (137) | Bubble numbers agree with exported `## N.` sections; 512 cap. |
| `packages/ui/components/html-viewer/composerYield.test.ts` (50) | Yield hysteresis. |
| `packages/ui/components/html-viewer/HtmlViewer.vimHud.test.tsx` (290) | Vim HUD message validation. |
| `packages/ui/utils/htmlChrome.test.ts`, `inputMethod.test.ts` | Minimal defaults, TTL expiry, legacy-record expiry, no cross-surface leakage. |
| `packages/editor/App.htmlHideTools.test.tsx` | End-to-end chrome wiring: minimal first render, restore/save race, persistence across mounts, keyboard reachability. |
| `packages/ui/utils/parser.test.ts:1755-1815` | Multi-target export format, injection resistance, byte-identical single-target output. |
| `packages/ui/utils/sharing.multiTarget.test.ts` | Share links deliberately drop anchors and multi-targets. |
| `packages/ui/hooks/useAnnotationDraft.seam.test.tsx:171-239` | Drafts round-trip `htmlAdditionalTargets` verbatim. |

Gap worth knowing: `preferenceTtl.ts` has no dedicated test file; it is covered indirectly through `htmlChrome.test.ts` and `inputMethod.test.ts`.

---

## 10. Adoption guidance for Workspaces

**Preferred path: consume, do not port.**

1. Use `HtmlViewer` from `@plannotator/ui` (exported via `packages/ui/components/html-viewer/index.ts`). It already exposes the host-facing surface: `applySharedAnnotations`, `removeHighlight`, `clearAllHighlights` (`HtmlViewer.tsx:531-535`).
2. Wire your backend through `configurePlannotatorUI()` at startup (`packages/ui/README.md:16-33`). Persistence, drafts, AI, and file loading are all seams.
3. If your host needs behavior the seams do not cover, add a seam to `@plannotator/ui` in this repo. That keeps both products on one implementation and Workspaces automatically inherits fixes like #1259.

**If you must adapt concepts into an existing surface instead, port in this order:**

1. The anchor model (section 4). This is the foundation; everything else is replaceable.
2. The overlay host and projection loop, including omission rules (a marker that cannot resolve shows nothing).
3. The reconcile triggers and all four performance gates (rAF coalescing, zero-work filter, generation-gated backoff with budget, viewport cull). Skipping these works in demos and melts on real mutation-heavy pages.
4. The parent-side DTO validation layer. Treat the annotated document as hostile input.
5. Numbering parity between on-page bubbles and exported feedback.

**Three mistakes to not repeat:**

- Do not mutate the annotated page's DOM, ever, for any reason, including "just this one wrapper element." That is the root cause both of the bugs this release fixed.
- Do not carry the `targetOrigin: "*"` posting into any context where the annotated content has a real origin. It is safe only inside an opaque-origin `srcdoc` sandbox with source-identity checks.
- Do not make anchors guess. Every heuristic that "probably" finds the element again eventually attaches someone's feedback to the wrong content, which is worse than showing nothing.

**Related work in flight (not in v0.26.8):** a phase-1 live-app annotation mode (annotating a locally running dev server through a loopback proxy, with the same bridge and anchor model) is complete on branch `feat/live-app-annotate` and pending PR. If Workspaces is considering live-app annotation, read `adr/research/SPIKE-local-app-annotation-20260810.md` first; the origin and security considerations there supersede several assumptions that are safe in the srcdoc-only world.

---

## Contact

Questions about this architecture: open an issue at `backnotprop/plannotator` or reach the maintainer directly. The fastest way to understand any specific behavior is to read the test that locks it down (section 9); the suites are written as executable specifications.
