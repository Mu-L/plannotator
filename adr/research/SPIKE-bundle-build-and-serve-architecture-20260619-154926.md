# SPIKE: How Plannotator builds, packages, and serves its UI bundle

Date: 2026-06-19
Status: Research (read-only). No code changed.
Method: 10-agent research workflow (4 architecture scouts → 5 traced theories → synthesis), plus direct measurement and verification by the lead.

This is the factual map. The optimization analysis lives in the companion spike: `SPIKE-bundle-optimization-theories-20260619-154926.md`.

---

## TL;DR

There are **two** built UI bundles, both produced as **single-file inlined HTML** by Vite + `vite-plugin-singlefile`. The plan/annotate surface ships `index.html` at **21,034,896 bytes raw / ~6.0–6.25 MB gzip**, of which **~20.3 MB (97%) is one inlined `<script>`**. It is embedded into the compiled binary as a text string and served on a **random OS-assigned port with zero cache headers**. The browser re-downloads (cheap, 10–16 ms on localhost) and then **re-parses/executes the full ~20 MB of JS on every open** — which is the ~5 s blank screen in issue #926. Network is not the cost; parse/execute is.

---

## The two bundles

| Bundle | Built from | Serves | Raw | Gzip | Inlined JS |
|---|---|---|---|---|---|
| `index.html` (PLAN editor) | `apps/hook` → `packages/editor/App.tsx` | plan review, annotate (file/url/folder), annotate-last, archive | 21,034,896 B | ~6.0–6.25 MB | ~20.3 MB (97.2%) |
| `review.html` (CODE REVIEW editor) | `apps/review` → `packages/review-editor/App.tsx` | code review subcommands only | 15,341,205 B | ~4.0 MB | ~14.6 MB |
| `redline.html` | `cp dist/index.html dist/redline.html` | **nothing** — byte-identical dead artifact | 21,034,896 B | — | — |

There is **no separate annotate bundle**: annotate reuses the plan editor (`index.html`) with mode flags. `redline.html` is built and copied by `apps/hook/package.json:8` but is **never imported or served** (`cmp` confirms it is identical to `index.html`; grep finds zero `with { type: "text" }` or server reference). "redline" exists only as an `EditorMode` string (`packages/ui/types.ts:7`). It is ~20 MB of pure dead build output.

---

## How the single-file build works

Both `apps/review/vite.config.ts` and `apps/hook/vite.config.ts` force everything into one file:

- `viteSingleFile()` — last plugin; rewrites the entry into one self-contained HTML.
- `assetsInlineLimit: 100000000` — inline **all** assets (fonts, images) as base64.
- `cssCodeSplit: false` — one `<style>` block (plan CSS = 3.78 MB; ~3.5 MB rules + ~0.28 MB data-URIs).
- `rollupOptions.output.inlineDynamicImports: true` — **collapse every dynamic import into the one chunk**. No code-splitting, no lazy loading.
- `worker: { format: 'es', rollupOptions.output.inlineDynamicImports: true }` — the Pierre highlight worker (`?worker&inline`) has a `import('shiki/wasm')` branch that Vite's default iife worker can't split, so the WASM/shiki branch is collapsed into the inlined worker blob too.

The net effect: **one HTML file, all JS/CSS/worker/fonts/assets inlined, zero deferred chunks, full parse on every open.**

---

## How it gets into the binary and the other runtimes

- **Claude Code (apps/hook):** `apps/hook/server/index.ts:146,150` does `import planHtml from "../dist/index.html" with { type: "text" }` and the same for `review.html`. Bun loads each as a string constant; `bun build apps/hook/server/index.ts --compile --no-compile-autoload-bunfig --target=<platform> ...` (`release.yml:79-100`) bakes both strings into each of the 6 per-OS standalone binaries. Only **two** HTML strings are embedded (`planHtml`, `reviewHtml`).
- **OpenCode (apps/opencode-plugin):** ships `plannotator.html` (= hook `index.html`) and `review-editor.html` (= review `index.html`) as package `files`, `readFileSync` at runtime (`index.ts:90/95`).
- **Pi (apps/pi-extension):** copies the same two files, `readFileSync` once at module load (`plannotator-browser.ts:68/74`).

`planHtmlContent` is served for plan, annotate, annotate-last, and archive (call sites at `index.ts` 484/1029/1227/1270/1328/1574/1637/1725/1829/1908); `reviewHtmlContent` only for review (831/1486).

---

## How it is served (the load path)

1. The Bun server binds a **random OS-assigned port** locally (`port = 0`) or fixed `19432` remote (`packages/server/remote.ts:11,65`).
2. The HTTP response for the document carries **only `Content-Type: text/html`** — **no `Cache-Control`, no `ETag`, and `Content-Encoding: identity`** (not gzipped on the wire) (`packages/server/index.ts:578`).
3. Localhost transfer of the 21 MB raw body measured at **10–16 ms** — download is negligible.
4. The browser then **parses and executes ~20.3 MB of JS up front** before first paint. Because each invocation is a new random port = a **new origin**, the browser cannot reuse its disk cache or its **V8 compiled-bytecode cache** across opens. So the parse cost is paid **every time**, not just first launch — exactly matching #926's "every time, not only first launch."

The `isLoading` gate (`packages/editor/App.tsx:384,1318`) currently renders a bare colored div during this window, so the user sees a featureless blank rather than a progress indicator.

---

## What is actually inside the plan bundle (measured weight)

Signature/position analysis of the ~20.3 MB inlined plan JS:

| Contributor | Approx weight in plan JS | Notes |
|---|---|---|
| **Shiki TextMate grammars** (via `@pierre/diffs` → shiki) | **~8.2 MB across 143 `JSON.parse()` calls** | Present in **both** bundles. Reached via `CodeFilePopout` (`App.tsx:87`). Likely the single dominant parse cost. |
| **Mermaid** (diagram rendering, eager) | **~5.2–7.3 MB (~37% of plan JS)** | Non-minified diagram chunks + its own bundled katex chunk (276 KB). Statically reachable from `Viewer.tsx:41`; loaded even when a plan has zero diagrams. |
| highlight.js (full, 156 languages) | marker span ~6.4 MB (overlaps other ranges) | Full language set; `hljs` 99 hits. |
| **xterm / @plannotator/webtui** (agent terminal) | ~225 KB inlined marker span (source footprint ~4.7 MB) | **Dead weight on plan review** — terminal is annotate-only (#941). Real `xterm-viewport/-screen/-accessibility` classes present in `index.html`, absent from `review.html`. |
| CodeMirror 6 / `@plannotator/markdown-editor` | smaller | Used by plan direct-edit (#928) and annotate; **not** plan-removable. |
| Base64 fonts (fontsource) | ~2.0 MB decoded, 36 blobs | Inlined into JS. |
| katex | 11 hits | Rides in transitively (the standalone KaTeX PR #878 is not in this release). |
| marked, DOMPurify, web-highlighter, lucide | smaller | — |

Plan-vs-review JS delta ≈ **5.4–5.7 MB**, attributable to xterm/webtui + CodeMirror + highlight.js. The ~8.2 MB Shiki grammars and most of Mermaid are common to both.

---

## Verified feasibility anchors (for the optimization spike)

- **The exact plan editor already builds multi-asset.** `apps/portal/index.tsx` imports the same `@plannotator/editor` (`packages/editor/App.tsx`) and `apps/portal/vite.config.ts` does **not** use `viteSingleFile`/`inlineDynamicImports`/`assetsInlineLimit`. The portal is a working proof that this App can ship as normal chunked assets.
- **`Bun.embeddedFiles` is a real API** (`typeof Bun.embeddedFiles === 'object'`), so a multi-asset `dist/` tree can be embedded into the compiled binary instead of a single string.

---

## Why single-file-inline exists (the invariants any change must respect)

- **No runtime build step / no node_modules at runtime** — the compiled standalone binary must carry the whole UI.
- **Random ephemeral port per invocation** — solves concurrent-session port collisions (`index.ts:592-603` EADDRINUSE handling); but it is the reason caching never helps locally.
- **URL-hash sharing** of plans/annotations (`packages/ui/utils/sharing.ts`) and the **backendless share portal** (`apps/portal`) — expect a self-contained document and must degrade with no `/api/*` backend.
- **Offline / air-gapped operation** — assets cannot be CDN-hosted; they must stay embedded/local.
- **Three runtimes** (binary / OpenCode npm / Pi npm) — any embedding+serving change must replicate across all three.

---

## Open questions carried into the optimization spike

1. Actual cold-load parse/execute attribution on #926's hardware (macOS/Chrome): how much is the 143 Shiki `JSON.parse` calls vs. Mermaid eager init vs. xterm/CodeMirror vs. React mount? The plan rests on Shiki+Mermaid being dominant — confirm with a flame chart.
2. Does Chrome's V8 reuse compiled-bytecode cache for content-hashed, `immutable`-cached assets across tab loads on a **stable** origin? The repeat-load payoff depends on this.
3. Can the 143 Shiki grammars be subset or lazy-loaded **independently** of the single-file question (possibly an invariant-safe large win)?
4. Does a multi-asset editor build run correctly in the **backendless portal** with lazy chunks served as static files, and still degrade when `/api/*` is absent?
