# SPIKE: Annotating a live locally-running web app

Date: 2026-08-10
Status: research only, no implementation
Author: research agent, commissioned by maintainer

## 1. Problem statement

Plannotator's annotate mode covers static content: markdown and plain-text files, static `.html` rendered in a sandboxed iframe, and URLs converted to markdown. The maintainer wants the same annotation experience against a live local web app (a Vite dev server on `http://localhost:5173`, a Next.js dev server, any local site): the user pinpoints elements in their running app, comments, and submits feedback into the agent session exactly like every other annotate flow. The sketched idea is a proxy that serves a wrapper around the target site and injects the annotation experience.

This spike evaluates four architectures, studies the two prior-art projects the maintainer owns (`~/oss/agentation`, `~/oss/react-grab`), and recommends a phased path.

## 2. What the existing architecture provides and requires

### 2.1 The raw-HTML annotate surface (what "the same experience" means)

- `packages/ui/components/html-viewer/HtmlViewer.tsx` renders arbitrary HTML in an `<iframe srcDoc sandbox="allow-scripts">` (line 620-643). The sandbox gives the document an opaque origin: no network trust, no parent DOM access. The bridge script plus annotation CSS is spliced into the document head as a string (`packages/ui/components/html-viewer/srcdoc.ts`, `injectIntoHead` at line 124), which is the existing precedent for "we inject our script into someone else's page".
- `packages/ui/components/html-viewer/bridge-script.ts` (3,053 lines, dependency-free string) implements everything inside the page:
  - Pinpoint selection: per-event hit testing with `deepElementFromPoint` (line 679) piercing open shadow roots, tiny-target promotion (`MIN_CAPTURE_SIZE = 16`, line 671, explicitly credited to agentation's pattern), SVG group promotion, shift-click multi-target selection.
  - The overlay model (this worktree is checked out on `feat/html-placed-markers`): the mouse pinpoint path never writes classes or styles onto author elements. Hover is a fixed-position outline box (`[data-plannotator-pinpoint-box]`), committed element pins are fixed-position numbered badges (`[data-plannotator-pin-badge]`, line 1115-1194). Overlay nodes are excluded from hit-testing by identity via the `overlayNodes` set (line 666), never by selector, so page markup cannot spoof its way in or out of targeting.
  - Durable element anchors that fail closed (line 1205-1372): a semantic ladder (unique `#id`, then identity attributes `data-testid`/`data-test`/`data-cy`/`data-qa`/`aria-label`/`role`/`href`/`alt`, then meaningful classes with generated-class filtering via `isLikelyGeneratedClass`, then a positional `tag:nth-of-type` path), every rung proved unique with a real query. Weak anchors must also match a captured text snapshot on restore (`resolveAnchorElement`, line 1352); a selector that cannot be proven unique ships no anchor at all.
  - Restoration: `find-and-mark` (line 475-526) resolves the anchor, scopes text search to it, falls back to document-wide text search, and finally badges the still-resolving element. `renderPinBadges` (line 1164) re-acquires a disconnected element through its anchor, which is exactly the primitive a re-rendering app needs.
  - Text annotations still mutate the DOM: drag selections wrap an inline `.annotation-highlight` `<mark>` (`applyMark`, used at line 451). Only element pins are overlay-projected. This distinction is load-bearing for live apps (section 5.1).
  - Badge repositioning runs only on scroll and resize (`schedulePinpointReconcile` wiring at lines 1112-1113). There is no MutationObserver; a static document never moves things without a scroll. A live app does.
- `packages/ui/components/html-viewer/useHtmlAnnotation.ts` is the parent-side trust boundary: `e.source === iframe.contentWindow` checks, `parseBridgeMessage` validation with hard caps (selector 1024 chars, anchor text 400, selection text 10,000, at most 16 additional targets; lines 106-123). Everything the page posts is treated as hostile. The bridge side accepts parent messages via `e.source !== parent` only (bridge-script.ts line 439); there is no origin check because a srcdoc sandbox has no meaningful origin. Both sides post with targetOrigin `"*"`.
- The composer, toolbar, quick labels, Ask AI hook, multi-target chips, and feedback export all live in the parent app and are driven entirely by these validated messages. Nothing in that chrome cares where the iframe content came from.

### 2.2 The annotate server and CLI

- `packages/server/annotate.ts` starts a Bun server, serves the editor HTML, exposes `/api/plan` (mode `annotate`, optional `rawHtml`/`renderAs`), `/api/feedback`, `/api/approve`, `/api/exit`, drafts, skills, external annotations, and the client-lease SSE for abandoned strict gates. Feedback settles a one-shot decision promise; the CLI prints it to stdout and the bang-prefix skill returns it to the agent. None of that changes for a live target.
- The server already handles WebSocket upgrades (agent-terminal PTY: upgrade at line 452, `websocket:` handler at line 969), so WS plumbing in Bun has in-repo precedent.
- `/api/html-assets/<token>/<path>` (`packages/server/html-assets.ts`) is the precedent for serving a page's subresources through a token-scoped route. A live-app proxy is the generalization of this idea from "sibling files on disk" to "everything the origin serves".
- The external-annotations API (`POST /api/external-annotations`, SSE stream) already lets an out-of-process producer feed annotations into a session in real time. This matters for option C.
- Binding: `getServerHostname()` returns `0.0.0.0` when `PLANNOTATOR_REMOTE` is active (`packages/server/remote.ts` line 150-152). The agent terminal is disabled by default in remote mode for exactly this reason (`PLANNOTATOR_AGENT_TERMINAL_REMOTE`). Any live-app proxy must follow that precedent, because a proxy bound beyond loopback relays the user's authenticated dev app to the network.
- CLI entry: `apps/hook/server/annotate-resolution.ts` classifies a target as a URL at line 78 (`/^https?:\/\//i`) and immediately converts it with Jina or fetch+Turndown. That branch is the clean insertion point for live-app detection.

### 2.3 What the experience requires from its host page, summarized

1. A script running inside the page (selection, anchors, overlay markers).
2. A message channel to the editor chrome, validated on both ends.
3. Re-injection or survival across page loads, and marker re-resolution across DOM churn.
4. No DOM mutation the page's own framework will fight.

## 3. Prior art

### 3.1 agentation (`~/oss/agentation`)

An annotation overlay for locally running dev apps; 374 commits since 2026-01, npm `agentation` v3.0.2 plus `agentation-mcp` v1.2.0. License is PolyForm Shield 1.0.0: source-available, forbids use in a competing product. Plannotator can learn from the ideas but must not lift code.

- Integration: a React component only (`<Agentation />`, dev-guarded, portals itself to `document.body`). No proxy, no script tag, no build plugin, no auto-injection. Everything else is transport: an optional local sync server on port 4747 (`mcp/src/server/index.ts`, node:http plus SQLite), an MCP stdio server with nine tools including a blocking `agentation_watch_annotations` long-poll so an agent can loop hands-free, a Claude Code `UserPromptSubmit` hook that curls `/pending` into context, and a plain webhook.
- Element identity (`package/src/utils/element-identification.ts`): a heuristic bundle captured at click time. Human-readable name, short DOM path (depth 4, shadow-aware, CSS-module hashes stripped), cleaned classes, nearby text, computed-style snapshot, accessibility info, bounding boxes. React fiber walk (`react-detection.ts`, hardcoded fiber tag table valid through React 19) yields a component hierarchy string, and `source-location.ts` reads `fiber._debugSource` for `src/Button.tsx:42` in dev builds. Output is markdown at four detail levels, designed to be greppable by an agent.
- Anchoring is coordinate-based: `x` as percent of viewport width, `y` as absolute document pixels, markers absolutely positioned in a zero-height document-top layer (separate fixed layer for fixed elements). Persistence is localStorage keyed per pathname with 7-day retention, so annotations survive reloads, HMR, and SPA navigation, but there is no MutationObserver and no re-anchoring: layout drift moves the pin off its element. Live element refs exist only for the in-flight session.
- UI is light DOM (no shadow root), isolated by hashed class names, z-index 99998/99999, and `data-agentation-root` exclusion attributes; native capture-phase listeners stop propagation for events inside the portal so host-app "click outside" handlers do not fire.
- Verdict for Plannotator: agentation proves the in-page opt-in model works and that fiber-derived component identity plus greppable markdown is the right agent-facing payload. It also demonstrates the two weaknesses Plannotator can beat: coordinate anchors that drift, and the friction of editing the user's app to install a component.

### 3.2 react-grab (`~/oss/react-grab`)

Element selection and identity for React apps; 1,492 commits since 2025-10, MIT license, npm `react-grab` v0.1.48 by Aiden Bai.

- Mechanism: fiber traversal via the author's `bippy` library, which rides the React DevTools global hook. `packages/react-grab/src/core/context.ts` uses `getFiberFromHostInstance(element)`, `getDisplayName`, upward `traverseFiber` for ancestor component names, `fiber.key` of the nearest keyed fiber for list-item identity, and `getSource`/`getOwnerStack` from `bippy/source`, which read React's dev-only debug fields and then fetch the bundle plus source map to symbolicate file and line. On Next.js, frames are POSTed to the dev server's symbolication endpoint; a HACK comment notes Vite line/column numbers from owner stacks are unreliable, so exact positions are only emitted on Next (file paths still resolve on Vite).
- Grabbed payload (`src/types.ts`): `{ tagName, componentName, content, commentText?, source: { filePath, lineNumber, columnNumber, componentName }, stackContext, frames }`, rendered as text like `[<a href="#">Forgot your password?</a> in LoginForm (at components/login-form.tsx:46:19)]`. In production builds it degrades deliberately to a CSS `selector:` hint plus surviving component names, and this degradation is e2e-tested.
- Integration paths: side-effect npm import or unpkg IIFE script tag (auto-inits on load, `window.__REACT_GRAB_DISABLED__` kill switch), a CLI `grab init` that detects next/vite/webpack/tanstack and injects a dev-guarded snippet into the entry file, and a Chrome MV3 extension with a MAIN-world content script. No build-time code transform.
- Overlay: one `<div data-react-grab>` on body, `position:fixed; inset:0; pointer-events:none; contain:strict`, max z-index, open shadow root for styles, canvas layer for lerped highlight boxes. While active it freezes React state updates by patching the dispatcher.
- Agent transport: clipboard with a custom `application/x-react-grab` MIME carrying structured JSON, plus a CLI daemon (`react-grab pull`) that polls the clipboard natively and blocks until the next grab, printing JSON lines for an agent loop; ships an agent skill and installs into detected agents.
- Verdict for Plannotator: MIT-licensed, so `bippy` (or `react-grab/core`) is a usable dependency, not just inspiration (verify bippy's own license before depending). "Button in src/components/Button.tsx:42, in LoginForm" is a categorically better feedback payload for a coding agent than any CSS selector, and `fiber.key` list identity plus component names would make Plannotator's anchors more durable, not just its exports richer. React-only today; Vue exposes `__vueParentComponent` and `type.__file` in dev, and Svelte dev builds stamp `__svelte_meta.loc = { file, line }` on elements, so equivalents exist but are separate work.

## 4. Architecture options

### Option A: reverse proxy plus HTML rewriting (the maintainer's sketch)

Shape that actually works: the annotate server keeps its own port (A) serving the editor app unchanged. A second Bun listener on port B, loopback only, mirrors the whole target origin with no path prefix: every request to `127.0.0.1:B/*` is forwarded to `localhost:5173/*`, and every `text/html` response gets the bridge injected before `</head>` (the exact `injectIntoHead` move srcdoc already does). The editor renders `HtmlViewer` in full-viewport mode with `src="http://127.0.0.1:B/"` instead of `srcDoc`, no sandbox attribute (it is the user's own app and needs cookies, storage, and same-origin XHR). The postMessage protocol is origin-agnostic already (`"*"` targetOrigin, source-identity checks), so the existing `useHtmlAnnotation` hook drives the proxied page unchanged, with tightening described below.

Why whole-origin on a dedicated port rather than a path prefix under port A: dev apps are full of root-absolute URLs (`/src/main.tsx`, `/_next/...`, `fetch("/api/...")`). A path prefix would require rewriting every URL in HTML, CSS, JS, and runtime-constructed strings, which is not achievable. A dedicated port makes the proxy origin-shaped: all root-absolute paths resolve to the proxy naturally and no body rewriting beyond head injection is needed.

Hard parts, honestly:

- WebSocket passthrough (HMR). Vite's client derives its WS URL from `location` by default, Next.js uses `/_next/webpack-hmr` on the page origin, webpack-dev-server defaults to `'auto'`. All three therefore connect to the proxy, which must upgrade and pipe frames both ways (Bun server WS plus a Bun WS client to upstream; precedent in the agent-terminal PTY bridge). Custom `server.hmr.port`/`clientPort` configs bypass the proxy and connect straight to the dev server, which actually still works because the dev server is alive; it only breaks for host-checked or TLS setups. Effort is real but bounded.
- Host checks. Vite's `allowedHosts` and Next's `allowedDevOrigins` guard against DNS rebinding. The proxy should forward `Host` as the upstream expects (rewrite to the target's own host:port) and set `X-Forwarded-*`; localhost is allowed by default everywhere, so the common case passes. Next 15.2+ logs or blocks cross-origin dev requests; forwarding the upstream Host avoids most of it, but this is a named compatibility risk to test per framework.
- Bodies and encoding. Injection requires decoded HTML: strip `Accept-Encoding` on HTML requests (or decompress), recompute `Content-Length`, and stream-inject on the first `</head>` (or after `<head>`) so streaming SSR (Next) is not stalled by buffering. Non-HTML responses stream through untouched, which covers SSE and large assets. HTTP/2 is a non-issue in practice (dev servers speak h1 unless configured for https; an https upstream needs a TLS-tolerant client and downgrades to http toward the browser).
- CSP and framing. Dev servers rarely send CSP, but apps can add it. The proxy must strip or amend `Content-Security-Policy` enough for the injected inline script (or inject `<script src="/__plannotator__/bridge.js">` served by the proxy itself, which is cleaner: cacheable, CSP-friendlier with a single `script-src` allowance, and keeps the HTML splice tiny). It must also replace `X-Frame-Options`/`frame-ancestors` with `frame-ancestors http://localhost:A http://127.0.0.1:A` so only the editor can embed the proxied app; this simultaneously defeats target-app anti-framing headers and prevents hostile websites from framing the proxy.
- Origin assumptions in the app. Relative and root-absolute fetches go through the proxy and keep cookies (localhost cookies are domain-scoped, not port-scoped, so `:B` sends the same cookies as `:5173`; `Set-Cookie` round-trips too). The failure cases: hardcoded absolute origins (`fetch("http://localhost:5173/api")` now becomes a cross-origin call from `:B` and needs the dev server's CORS to allow it), secondary local APIs with CORS pinned to `http://localhost:5173` exactly, and OAuth flows whose registered `redirect_uri` is `:5173` (the callback lands the user outside the proxy and the session silently loses the wrapper). None of these are fixable generically; they are the documented boundary of the approach and the reason an escape hatch (option C transport) should exist.
- Service workers. A SW registered by the proxied page registers on the proxy origin and caches proxied (already injected) responses, so injection survives; stale SW state from `:5173` does not apply because it is a different origin. Residual risk: apps whose SW serves a prebuilt offline shell that never hits the network again after first load; low likelihood in dev.
- Navigation. SPA client routing never reloads the iframe, so the bridge persists; full reloads and hard navigations get re-injected by the proxy on the next HTML response, and the bridge's ready handshake already makes `HtmlViewer` re-send state and re-apply annotations (`iframeReadyVersion`). What is genuinely new: annotations must be scoped to a page (store the pathname on the annotation, restore only those matching the bridge's current page, label exports per page), which agentation's per-pathname keying validates as the right model.
- Frame-busting. Apps that check `window.top !== window.self` break the iframe wrapper. Rare in dev apps; the mitigation is the option C transport (top-level tab, no iframe), not more proxy cleverness.

Security model: the proxy binds `127.0.0.1` unconditionally, independent of `PLANNOTATOR_REMOTE` (same posture as the agent terminal: live-app mode is disabled or loopback-pinned under remote, never rebound to `0.0.0.0`, because it would relay an authenticated app to the network). The proxy validates the `Host` header (reject non-localhost values, which also blunts DNS rebinding), sends the `frame-ancestors` policy above, and the injected bridge gains what srcdoc never needed: a per-session token in its injected config, echoed on every message and checked by `useHtmlAnnotation`, plus real origin checks on both sides (bridge posts to the editor origin instead of `"*"` and verifies `event.origin` on parent messages; the parent verifies `event.origin` is the proxy origin). The existing payload validation and size caps stay exactly as they are; a live app is the user's own code, but the trust boundary should not be relaxed just because the content is friendlier.

### Option B: iframe without proxy

Editor chrome on top, `<iframe src="http://localhost:5173">` directly. Cross-origin means no DOM access, no script injection, and no way to run the bridge, so no element selection, no anchors, no markers; the best achievable is screenshot-coordinate commenting, which throws away everything that makes Plannotator feedback good. `X-Frame-Options`/CSP from the app cannot be stripped. A postMessage-cooperative variant requires the target to include a script, which is option C with an extra iframe. Not viable as an architecture; only useful as a degraded fallback rendering.

### Option C: script-injection opt-in (the agentation model, with Plannotator's server)

The developer adds one dev-guarded line (script tag pointing at `http://127.0.0.1:<port>/__plannotator__/bridge.js`, or a tiny published Vite/Next plugin that injects it, exactly like `grab init`). The bridge is the same code as option A's, with the postMessage transport swapped for WebSocket/HTTP back to the annotate server; the existing external-annotations API and SSE stream already carry most of what is needed server-side. The page runs top-level in the user's normal tab, no proxy, no iframe.

Strengths: zero proxy failure modes. HTTPS dev servers, origin-pinned CORS, OAuth, frame-busting, service workers, host checks: all irrelevant. This is the reliability ceiling.

Weaknesses: friction (per-project edit, or per-project plugin install, and a port the snippet must discover since annotate servers use random ports; a fixed well-known secondary port or a config file would be needed), and chrome. Either the composer/toolbar UI is rebuilt as an injectable in-page bundle (large: the composer, chips, quick labels, Ask AI, and settings all live in the React editor app) or the UX splits across two surfaces (pinpoint in the app tab, compose and submit in the editor tab), which is workable but clumsier than the wrapper. Auto-injection via a published plugin gets close to zero-config for Vite/Next projects but is a new published artifact to version and maintain.

The right role for C is not "instead of A" but "A's transport escape hatch": the same bridge bundle, served by the same server, documented for apps the proxy cannot wrap.

### Option D: browser extension or CDP injection

CDP requires the user's browser to run with a debugging port (relaunch, dedicated profile) or Plannotator to launch a managed browser; an extension requires store distribution, review cycles, and per-browser maintenance, and react-grab's MV3 extension shows the cost. Both violate the zero-install, "hook plus browser" character of Plannotator, and neither adds capability beyond options A/C once injection exists. Rejected; revisit only if a managed-browser product direction ever appears.

## 5. Going deeper on the recommended pair (A primary, C as escape hatch)

### 5.1 How the existing bridge and overlay port

- Overlay-only is mandatory in live mode. Inline `<mark>` wrapping splits text nodes React owns; React reconciliation then throws (removeChild/insertBefore on moved nodes) or silently discards the mark. Live mode must force pinpoint input (element pins, overlay boxes) and must not call `applyMark`. Drag-to-select text can still be offered later by projecting selection rects onto the overlay instead of wrapping, but phase 1 should ship pinpoint-only. The placed-markers branch made exactly the right move at exactly the right time: everything the mouse path draws is already viewer-owned overlay.
- Reposition must become churn-aware. Today badges reposition on scroll/resize only (bridge-script.ts lines 1112-1113). A live app moves elements without scrolling (data loads, layout shifts, route transitions). Add a MutationObserver (subtree, childList, attributes) plus a coalescing rAF that calls the existing reconcile; `renderPinBadges` already re-resolves disconnected elements through anchors, so the re-acquire primitive exists and is tested. Idle cost is near zero on a quiet page; a storming page (animations) needs the observer callback to stay O(1) and defer all work to one rAF.
- Anchor durability across HMR and reconciliation: the fail-closed ladder behaves well. `id` and `data-testid` rungs survive any re-render; the generated-class filter (`isLikelyGeneratedClass`) already rejects CSS-module hashes; Tailwind-heavy DOMs will often fall through to positional paths guarded by text snapshots, which correctly refuse to restore when a list reorders (the pin disappears rather than lying). HMR that replaces a component's DOM wholesale re-resolves on the next reconcile. The honest weak spots: virtualized lists (elements unmount offscreen; pins correctly hide, which reads as flicker), text-free icon buttons without identity attributes (anchor is refused by design), and cross-reload restoration when the app renders differently per session.
- Component identity makes anchors more durable, not just exports richer. Adding a fiber-derived rung via bippy (component displayName, nearest `fiber.key`, owner file path) gives identity that survives class and structure churn, because it keys on what the developer wrote rather than what the DOM looks like. Concretely: extend the anchor DTO (`HtmlElementAnchor` in `packages/ui/types.ts`, validated in `parseHtmlElementAnchor`) with an optional `react?: { component, file, line?, key? }` block, captured at click time, used (a) verbatim in exported feedback ("Button in src/components/Button.tsx:42, in LoginForm"), and (b) as a restoration assist: re-resolve by walking fibers for the same component plus key when the CSS rung fails. Dev builds only; absence degrades to today's behavior. Vite gives reliable file paths but unreliable line numbers (react-grab's finding); Next symbolicates precisely. Vue (`__vueParentComponent`, `type.__file`) and Svelte (`__svelte_meta.loc`) equivalents exist for later.
- Navigation and multi-page sessions: annotations gain a `pageUrl` (pathname) field; the bridge reports its location on ready and on history changes; the editor shows which page each annotation belongs to and only pushes matching ones down for restoration; exports group by page. The ready-handshake re-send loop in `HtmlViewer` already handles reload re-initialization.

### 5.2 CLI and UX surface

- `plannotator annotate http://localhost:5173` should probe before converting: if the URL host is loopback (localhost, 127.0.0.1, ::1) and a quick fetch returns HTML, start live-app mode; `--static` forces today's Jina/Turndown conversion, `--app` forces live mode (and errors clearly if unreachable). Non-loopback URLs keep the current pipeline untouched. Implementation point: the `isUrl` branch of `apps/hook/server/annotate-resolution.ts` (line 78).
- Server: a new `mode: "annotate-app"` in `startAnnotateServer` options; the server starts the proxy listener, and `/api/plan` returns `{ mode: "annotate-app", appUrl: "http://127.0.0.1:B/", targetUrl }` instead of `rawHtml`. The editor reuses the full-viewport HTML surface (`renderAs: 'html'` path in `packages/editor/App.tsx`) with `src` instead of `srcDoc`.
- Feedback and submission are unchanged: the same composer, the same `/api/feedback` settle, the same stdout decision to the agent session, the same drafts. Session lifecycle should mirror folder annotate: the server stays up while the user browses and pins across pages, and Submit ends the session. The strict-gate client-lease machinery is reusable if live-app gates are ever wanted; not phase 1.
- Version history: live pages have no meaningful file content to snapshot; `PLANNOTATOR_ANNOTATE_HISTORY` behavior should treat live-app sessions like URL sessions (no history writes), which is already the rule for URL targets.

### 5.3 Interaction with remote mode

`PLANNOTATOR_REMOTE` binds the annotate server to `0.0.0.0`. The proxy must never follow: either live-app mode is unavailable under remote (clear error suggesting the option C script tag, which the user can point at a tunneled port themselves) or the proxy stays loopback-pinned and the editor warns that the embedded app is only reachable from the same machine. The first is simpler and matches the `PLANNOTATOR_AGENT_TERMINAL_REMOTE` precedent of off-by-default for anything that widens exposure. `PLANNOTATOR_URL_HOST` must not be applied to the proxy URL for the same reason.

## 6. Recommendation

Build option A (loopback reverse proxy, whole-origin mirror on a dedicated port, bridge injected server-side, editor iframe wrapper reusing the existing annotate app) as the flagship zero-config experience, with the bridge transport abstracted so the identical bundle also works as an option C script tag for apps the proxy cannot wrap. Skip B (not viable) and D (out of character, no added capability).

Rationale: A is the only zero-config path that reuses the entire existing chrome (composer, toolbar, multi-select, Ask AI, drafts, submission) without rebuilding it as an injectable, and the postMessage protocol plus overlay model port with modest, well-understood changes. Its compatibility long tail is real but bounded, and every failure case has the same answer (the C escape hatch), which is cheap because it shares the bridge. Agentation validates the product shape and the agent-facing payload; react-grab (MIT) supplies the component-identity mechanism that turns "div.flex > button:nth-of-type(2)" into "Button in src/components/Button.tsx:42", which is the single biggest feedback-quality differentiator available here.

## 7. Phased plan

Phase 1: proxy plus pinpoint annotation (M/L)
- Loopback proxy listener: HTTP forwarding, streaming head injection of a `/__plannotator__/bridge.js` script tag, header hygiene (CSP amend, frame-ancestors replace, Host rewrite, Accept-Encoding strip on HTML), WS passthrough for the three mainstream HMR paths.
- Bridge served as a compiled standalone bundle (extracted from the srcdoc string constant; transport shim: postMessage today, config-injected token and origins).
- Live-app mode in `HtmlViewer` (src, no sandbox, full-viewport, pinpoint-only input, resize messages ignored), MutationObserver reconcile in the bridge, pageUrl on annotations, single-page restore.
- CLI probe and `annotate-app` server mode; remote-mode hard-off.
- Exit bar: annotate a Vite React app and a Next app across HMR edits, reload, and SPA navigation; feedback reaches the agent unchanged.

Phase 2: component and source identity (M)
- Optional fiber rung via bippy in the bridge (React first): component name, owner file:line where resolvable, `fiber.key`; anchor DTO extension plus validation caps; export enrichment; fiber-assisted re-resolution.
- Per-page annotation browser in the editor sidebar; export grouped by page.

Phase 3: escape hatch and plugin (S)
- Document the script-tag integration against the same served bridge; WS/HTTP transport to the annotate server reusing the external-annotations API; optional tiny published Vite plugin that injects the tag in dev.

Phase 4: breadth (M, only on demand)
- Overlay-projected text selection (drag) without DOM mutation; Vue/Svelte identity rungs; screenshot capture on pins; multi-repo/monorepo niceties.

## 8. Risks, ranked by likelihood

1. Proxy compatibility long tail (likely, survivable): origin-pinned CORS to secondary APIs, hardcoded absolute origins, OAuth redirect_uri, host-checked dev servers, exotic HMR configs, streaming edge cases. Mitigation: per-framework smoke tests in CI images, a visible "this app may not proxy cleanly" diagnostic, and the option C escape hatch. This risk cannot kill the feature but will generate a steady trickle of issues.
2. Marker durability perception (likely, survivable): virtualized lists, identity-free icon buttons, and Tailwind-only DOMs will produce pins that fail closed (vanish) and read as bugs. Mitigation: phase 2 fiber identity, plus honest UI ("target not currently on page") instead of silent absence.
3. DOM-mutation regressions (certain if unguarded, fatal to UX): any inline-mark path leaking into live mode will corrupt React apps. Mitigation: hard mode gate in the bridge (live config disables applyMark), covered by tests.
4. Remote-mode exposure (unlikely, catastrophic): a proxy bound beyond loopback relays the user's authenticated app. Mitigation: live mode refuses to start under `PLANNOTATOR_REMOTE`; proxy binds 127.0.0.1 unconditionally; Host-header validation; test asserting the bind.
5. Scope creep toward in-page chrome (moderate, product risk): rebuilding the composer inside the page duplicates the editor and drifts. Mitigation: keep C minimal (transport only) and let the editor tab remain the chrome.
6. License contamination (low, avoidable): agentation is PolyForm Shield; concepts only, no code. react-grab is MIT; verify bippy's license before adding the dependency.

## 9. Open product questions for the maintainer

1. Should loopback URLs default to live mode, or stay static-convert with `--app` opt-in for a release or two?
2. Is pinpoint-only acceptable for live mode at launch, or is overlay-projected text selection a phase 1 requirement?
3. Multi-page sessions: submit one combined feedback body grouped by page, or scope a session to the entry page and treat navigation as out of scope initially?
4. Does the compound/skill ecosystem need a named surface for this (e.g. `/plannotator-annotate --app`), or is transparent URL detection enough for the slash-command hosts?
5. Appetite for a published `@plannotator/vite-plugin` (phase 3) as a maintained artifact, versus documentation-only script tag?
6. Should live-app annotations feed the external-annotations API shape so other tools (lint agents) can co-annotate the same session, or stay on the bridge-only path?
7. Remote mode: hard-off (recommended) or loopback-pinned-with-warning?
