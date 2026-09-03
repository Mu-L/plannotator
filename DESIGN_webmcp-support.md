# Design: WebMCP support

Status: proposal, no implementation. Investigated 2026-08-25 against the WebMCP checkout at `/Users/ramos/oss/mcp/webmcp` (134 commits, last `bd99438` on 2026-08-25), Chrome's developer docs (`developer.chrome.com/docs/ai/webmcp*`, last updated 2026-08-20), `webmcp-types@0.1.5` (published 2026-08-20), and the current Plannotator main checkout. Revised the same day around the maintainer's agent-efficiency principles (decisions are human; fewer hops; rich responses with nudges; mutations return state; modern agent-API shape; multi-document awareness). File references are `path:line` in those trees.

The framing this document answers: WebMCP is coming out of Google, Microsoft and the W3C WebML CG, and the browsers that matter for Plannotator's users (Chrome and Edge today, agent-embedded browsers such as Codex's and Claude Code's next) will let a browser-integrated agent call in-page tools instead of scraping the DOM. Plannotator is the page that agent will be looking at during a plan review or code review. What should Plannotator register, in which direction, with which invariants, and where does it live so a browser without WebMCP sees zero change?

Three facts drive everything below:

1. **Plannotator's own trust boundaries already do the hard security work for free.** The raw-HTML annotate iframe is `sandbox="allow-scripts"` with no `allow` attribute (`packages/ui/components/html-viewer/HtmlViewer.tsx:824`), which gives the framed page an opaque origin; the live-app iframe is cross-origin by port with no `allow` attribute either. WebMCP is gated by the `tools` permissions policy whose default allowlist is `'self'` (`index.bs:1309-1313`), so in both cases the annotated page cannot register a tool at all (`registerTool()` rejects with `NotAllowedError`, `index.bs:657-658`). A hostile page cannot impersonate Plannotator's tools unless Plannotator adds `allow="tools"` to an iframe. It must never do so on the srcdoc surface, and adding it to the live-app surface is a deliberate phase-3 decision, not a default.
2. **The API surface is small and the churn is real.** Three method names, one event, two annotations. But the entry point has been renamed three times in a year (`window.agent` → `navigator.modelContext` → `document.modelContext`), `provideContext()`/`clearContext()`/`unregisterTool()` were all removed in March 2026, `registerTool()` only started returning a promise in June, and `executeTool()` changed its input from a JSON string to an object on 2026-08-17 (the Chrome docs still show the string form). The design therefore isolates every spec name in one file and treats the rest of the codebase as spec-agnostic.
3. **The agent is a reader and a commenter; the human decides.** No tool approves, denies, sends, or closes anything. That removes every consent question from the design and makes the catalog small: one rich read that returns the whole situation, one batch comment mutation that returns what it made, and a way to point the human at something. Every response carries nudges computed from state the page already holds, so the agent learns what changed on the call it was going to make anyway.

---

## 1. WebMCP in one page

### 1.1 What it is

WebMCP (`index.bs:113-115`) lets a web page expose client-side JavaScript functions as **tools** — a name, a natural-language description, a JSON Schema for the input, and an `execute` callback — that a browser-integrated agent can discover and invoke. The page becomes "an MCP server that implements tools in client-side script instead of on the backend" (`README.md:74`). It deliberately shares vocabulary with MCP (tools, input schema, annotations) but is **not** MCP: there is no transport, no JSON-RPC, no server. The spec explicitly does not prescribe how a browser hands tools to its agent ("Browsers are free to distill and expose tools via Model Context Protocol, other proprietary function calling methods, or any other way", `index.bs:1387-1390`).

The motivating contrast with backend MCP (`README.md:14-26`): backend integrations bypass the UI and force the developer to replicate auth and state on a server; WebMCP keeps the human, the page and the agent in one shared context, reusing the page's existing client code. Goals (`README.md:85-91`): human-in-the-loop cooperation, reliable agent actuation, no disintermediation, code reuse. Non-goals (`README.md:93-98`): headless, fully autonomous, replacing MCP, replacing the human UI. Plannotator's plan and code review are the archetype of the intended use: a human reviewer with an agent assistant on a page whose actions (annotate, approve, deny) already exist as client functions.

### 1.2 The precise API (spec `#api`, `index.bs:565-1245`)

Entry point: `document.modelContext` — `[SecureContext, SameObject] readonly attribute ModelContext` on `Document` (`index.bs:585-588`). One `ModelContext` per document, created with the document; nothing persists across navigations (questionnaire Q6). It is an `EventTarget`:

```webidl
[Exposed=Window, SecureContext]
interface ModelContext : EventTarget {
  Promise<undefined> registerTool(ModelContextTool tool, optional ModelContextRegisterToolOptions options = {});
  Promise<sequence<RegisteredTool>> getTools(optional ModelContextGetToolOptions options = {});
  Promise<DOMString> executeTool(RegisteredTool tool, optional object inputObject = {}, optional ModelContextExecuteToolOptions options = {});
  attribute EventHandler ontoolchange;
};
```
(`index.bs:602-611`)

**Tool descriptor** (`ModelContextTool`, `index.bs:1057-1078`): `name` (required; 1–128 chars, only `[A-Za-z0-9_.-]`, `index.bs:157-159`, `:672-675`), `title` (optional, for UA UI), `description` (required, non-empty), `inputSchema` (optional JSON Schema object, stored stringified), `execute` (required: `(inputObject, { signal }) => Promise<any>`), `annotations` (`readOnlyHint`, `untrustedContentHint`, both default false, `index.bs:1068-1071`). No `outputSchema` yet (issue #9), no consequential/destructive hint yet (issue #176, planned per questionnaire Q4).

**Registration** (`index.bs:643-776`): rejects with `InvalidStateError` if the document is not fully active, a tool of that name already exists, or name/description are empty/invalid; `SecurityError` if the agent cluster is not origin-keyed (i.e. `document.domain` is enabled; `file:` is exempt, `index.bs:652-655`) or an `exposedTo` origin is not potentially trustworthy; `NotAllowedError` if the `tools` permission is denied; `TypeError` if `inputSchema` does not JSON-serialize. **Unregistration is only via `AbortSignal`** (`options.signal`): aborting runs "unregister a tool" synchronously in the abort steps and rejects the registration promise with the abort reason (`index.bs:718-729`). A `toolchange` event is fired at every document in the tree the tool is exposed to (`index.bs:336-357`).

**Execution** (`index.bs:462-538`): the browser parses the arguments as JSON, requires an object, creates an `AbortController` per execution, and invokes `execute(inputObject, { signal })`. The return value is **JSON-serialized**; a value that cannot be serialized (including `undefined`, since `JSON.stringify(undefined)` is `undefined`) or a rejected promise both surface to the caller as a bare `UnknownError` with no message (`index.bs:518-536`, `:1015-1020`; "Support more granular errors" is an open issue at four sites). Consequence for us: **tools must always return a JSON value, and application errors must be returned as data, never thrown** — this is also Chrome's guidance ("Add descriptive errors to your function code to allow the model to self-correct", best-practices). Cancellation: the caller's `signal` aborts the execution's controller (`index.bs:243-288`); since Chrome 153 an unregistration no longer cancels in-flight executions (imperative-api doc, `#248`).

**Discovery by in-page agents** (`getTools`, `index.bs:778-891`): returns `RegisteredTool` dictionaries (`name, title, description, inputSchema` deep copy, `window`, `origin`, `annotations`) for tools in the caller's frame tree that are same-origin, or cross-origin ones both listed in `fromOrigins` and `exposedTo` the caller. Sorted by name. Built-in browser agents do **not** use `getTools`; they take an implementation-defined "observation" of every document in the tab (`index.bs:1330-1397`) that carries the tool map plus screenshots/accessibility data, and are expected to convey each tool's origin to the model (Advisement, `index.bs:1392-1395`). `executeTool` runs the callback in the owner document's realm and rejects `UnknownError` on any mismatch (cross-top-level, wrong origin, missing tool, not exposed) and `NotSupportedError` for opaque-origin targets (`index.bs:893-1050`).

**Scoping** (`#permissions-policy`, `index.bs:1309-1313`; README `:312-340`): policy-controlled feature `tools`, default allowlist `'self'` — top-level documents and same-origin iframes have it; cross-origin iframes need `<iframe allow="tools">`. Tools default to being exposed to the registering document, same-origin documents in the tree, and the built-in agent; `exposedTo: [origins]` widens that to specific secure origins. A sandboxed iframe has an opaque origin, so it is never `'self'` and never same-origin with anything; `executeTool` additionally refuses opaque target origins outright. Open question (README `:470`): a `native-agent` keyword so authors control exposure to the built-in agent, with the running idea that tools registered **in iframes** are by default *not* exposed to it — favorable to a host like Plannotator.

**Declarative path** (`declarative-api-explainer.md`; Chrome declarative-api doc): `<form toolname tooldescription [toolautosubmit]>` with `toolparamdescription` on controls; the browser synthesizes the input schema from the form (algorithm is a TODO in the spec, `index.bs:1252-1259`), fills it, and either focuses the submit button for the human or submits (`toolautosubmit`); `SubmitEvent.agentInvoked` + `respondWith(promise)` hand a result back; `:tool-form-active` / `:tool-submit-active` pseudo-classes and `toolactivated` / `toolcancel` events. Response-after-navigation semantics are unresolved (issue #135). Plannotator's actions are not forms, so this path is not used here; it is noted because agents will see declarative tools on the *annotated* page in phase 3.

**Service workers** (`docs/service-workers.md`): a supplemental explainer for background providers with sessions and JIT installation; still uses the old `self.agent.provideContext` shape and is not relevant to a per-session localhost app. It is, however, the only place the spec family discusses agent *session identity* (`clientInfo.sessionId`, `:219-238`), and it does so for service workers only: page tools receive no caller identity. That shapes how "since your last read" can be tracked (§4.4).

### 1.3 Lifecycle, as Plannotator should think of it

Register on mount → the browser observes the tab → the user asks the agent → the agent calls a tool → `execute` runs in our realm with our React state → we return JSON → unregister on unmount via `AbortController`. Tools can be dynamic ("Register tools when they're useful in a certain page state, then unregister when the tool is no longer usable", Chrome best-practices), but the timing of a browser agent's re-observation after `toolchange` is implementation-defined (`index.bs:1402-1406`), which is why this design keeps the tool list stable within a surface and puts state into responses instead (§3.6).

### 1.4 Security model, what it gives and what it does not

The spec's security section is non-normative (`index.bs:1409-1799`) and is candid: the risks are prompt injection through tool metadata and outputs (`#prompt-injection`), tools whose declared intent does not match behavior (`#misrepresentation-of-intent`), over-parameterized tools harvesting personalization data (`#privacy-leakage-over-parameterization`), and unresolved same-origin-boundary questions (`#violation-same-origin-boundaries`, a TODO). Baseline assumption: the agent inherits the user's identity, extended context, and cross-site context (`index.bs:1442-1452`).

What the platform gives a provider today: origin isolation (permission policy + `exposedTo` + per-origin attribution to the model), `readOnlyHint` so an agent can skip confirmation for reads, `untrustedContentHint` so an agent can spotlight or sanitize untrusted output (`#mitigation-untrusted-annotation`), name-length limits, and cancellation. What it does **not** give: any user-consent primitive. There is no user-activation requirement, no "consequential" hint yet (#176), no elicitation (`requestUserInteraction`/`ModelContextClient`, issue #165/#50, referenced by Chrome's secure-tools page but absent from the current spec text). This design sidesteps the gap entirely by exposing no consequential tools.

### 1.5 Status (honest)

- Spec: W3C WebML Community Group draft (`CG-DRAFT`, `index.bs:5-7`), editors from Microsoft and Google. No WPT results yet. Rename history above. Open issues cited from the text: #9 outputSchema, #41/#81/#86 multimodal, #82 streaming, #92 schema validation, #135 cross-document response, #146 `toolactivated`/`toolcanceled`, #161 skills, #165 elicitation, #176 consequential hint, #182 declarative errors, #224 `title` default, #227 cross-top-level execution.
- Chrome: origin trial live in Chrome 149 (`implementation-status.md:15`); local use via `chrome://flags/#enable-webmcp-testing`; requires origin-isolated documents (no `document.domain`) and the `tools` policy. Chrome 153 preserves in-flight executions after unregistration. Tooling: "Model Context Tool Inspector" extension (monitor registrations, call tools manually), `webmcp-types` typings, `usewebmcp` React hooks (v5.0.1, from the MCP-B project), Angular experimental support.
- Edge: origin trial in Edge 150. Brave: experimental in Leo. Firefox and WebKit: standards positions requested, no implementation.
- Types: `webmcp-types@0.1.5` declares `Document.modelContext?: WebMCP.ModelContext` as optional and matches the spec IDL (no `executeTool` in the typings yet).
- Origin-trial caveat that matters to Plannotator specifically: OT tokens are bound to an origin, and a Plannotator session runs on a random localhost port, so no token can cover it; during the trial, a Plannotator user needs the Chrome flag. This is a transient inconvenience, not a design constraint, and agent-embedded browsers ship the API unflagged.

---

## 2. Where it fits Plannotator

### 2.1 Direction (a): Plannotator as a WebMCP provider

This is the primary fit. A Plannotator session is a top-level, same-origin, secure-context (`http://localhost:<port>` is potentially trustworthy) document whose state — the document, its blocks, every annotation, the linked-doc cache, the open composer, the on-disk staleness flag — is already in memory in one React tree. A browser agent asked "what did I flag in this plan and is anything missing" today scrapes a DOM built for humans; with tools it gets the situation in one structured response.

The division of labor is fixed: **the agent reads, comments, and points; the human decides.** No tool approves, denies, sends feedback, closes the session, stages a file or marks a file viewed. When the agent believes the plan is ready it says so in a document-level comment or a one-line nudge to the human (§3.2, `nudge_user`), and the human clicks Approve. That is not a limitation to work around later; it is the product. The decision handlers keep their full confirmation ladder for the buttons (`packages/editor/App.tsx:4479-4541`) and nothing in the provider references them.

Tools bind to in-page state and handlers, never to HTTP:

| Surface | Bound state and handlers | Invariants preserved |
|---|---|---|
| Plan review / annotate (md, html, live) | `displayedMarkdown`, `blocks` (`App.tsx:330`, `:349`), `allAnnotations` (`:1665`), `handleAddAnnotation` (`:3687`), `handleEditAnnotation` (`:3797`), `handleDeleteAnnotation` (`:3777`), `handleSelectAnnotation` (`:3711`), `linkedDocHook.getDocAnnotations()` / `open()` (`useLinkedDoc.ts:140-166`), `fileBrowser` (`useFileBrowser.ts:27-40`), `livePageUrl` (`:486`), the source-file watch (`:2705`), the open comment composer (`useAnnotationHighlighter` / `useHtmlAnnotation`) | `documentReadOnly` no-op; HTML/live surfaces are comment-only (creation clamp, `useHtmlAnnotation.ts:535-547`); `pageUrl` stamping on live (`:3692-3695`); drafts autosave through `useAnnotationDraft` untouched; the client lease is untouched (a tool call is activity inside the one connected surface) |
| Code review (phase 2) | `ReviewState` (`packages/review-editor/dock/ReviewStateContext.tsx:32-258`): `files`, `annotations`, `openDiffFile`, `onAddAnnotationForFile`, `onAddFileCommentForFile`, `onEditAnnotation`, `onDeleteAnnotation`, `onNavigateToAnnotation`, guide state | PR scope stamping (`withPRContext`), `isLineRangeInPatch` range validation, `annotationMatchesPrScope` on reveal |

The backend analog already exists and is instructive: `/api/external-annotations` (SSE stream, `packages/core/external-annotation.ts`) is how a *backend* agent adds review comments, with a `source` label rendered in the panel and the export. WebMCP is the front-end analog for an agent looking at the same page as the human; tool-created comments carry `source: "browser-agent"` so provenance is identical.

### 2.2 Direction (b): Plannotator as a consumer

**Raw HTML (srcdoc):** impossible without weakening the sandbox, and the sandbox is the security boundary (`srcdoc.ts:123-128`). An opaque-origin document is denied the `tools` feature, and even with `allow="tools"` `executeTool` refuses opaque origins. Do not pursue.

**Live app (`annotate-app`):** feasible, and interesting, but not in the way one might first assume. The proxied app is cross-origin (proxy port ≠ editor port) so its tools are denied by default. What is under our control: the injected bridge (`/__plannotator__/bridge.js`, `live-proxy-core.ts:36`) already runs as same-origin code inside the app document and already has an authenticated channel to the parent (`bridge-script.ts:237-245`, ingest at `useHtmlAnnotation.ts:508-515`). If the live iframe carried `allow="tools"`, the bridge could call `document.modelContext.getTools()` in the app's realm, listen to `toolchange`, and relay descriptors to the editor as **untrusted data** for display. That yields a genuinely new review capability: *reviewing a WebMCP integration* — the reviewer sees the tools the app registers on each page and annotates one by name; the browser agent, through `read_document`, sees the same list and the human's comments on it. Execution of the app's tools from Plannotator is out of scope: Ask AI runs server-side (`packages/ai/`), and the "lethal trifecta" argument in `docs/service-workers.md:250-256` applies. Phase 3, enumeration only, behind a deliberate `allow="tools"` decision.

---

## 3. Tool catalog and flows

### 3.1 Design constraints (the maintainer's principles, made operational)

1. **Decisions are human.** No approve/deny/send/close/stage/viewed tools. `nudge_user` and a document-level comment are the agent's only ways to say "ready".
2. **One call in the common case.** `read_document` returns session, text, outline, annotations (anchored, contextualized, with novelty), other active documents, and nudges. Mutations return the resulting objects plus fresh nudges. Cursors exist only for large documents (§3.5).
3. **Nudges on every response.** `nudges: Nudge[]` is filled by the engine from state the page already has (§4.4); no nudge ever requires a second call to discover, and every nudge names the ids/paths needed to act on it.
4. **Mutations return the new state**, batched with per-item results and idempotency keys.
5. **Agent-API shape.** Envelope `{ ok, data, nudges, error? }`; stable annotation ids (already `generateId`); `requestId` idempotency; `since` watermarks; descriptions written for an LLM reader with "use when / do not use when"; zero-argument calls are the useful ones; hints set honestly (§3.6).
6. **Multi-document awareness** without polling: the response tells the agent which sibling documents the human is active on and what changed there.
7. **Ownership.** The agent may update or remove only annotations it created (`source === "browser-agent"`). The human's comments are read-only to it. This is what makes "no confirmation dialogs" safe.

### 3.2 Phase-1 catalog (plan review and every annotate surface)

Names are bare here; the engine prefixes them (`plannotator.` by default). Six tools, one of them folder-only.

| Tool | For | Not for | Hints |
|---|---|---|---|
| `read_document` | Everything an agent needs to know about the page in one call: what session this is, the document text (or the current page for a live app), its outline, every annotation with its anchored text and context, what is new since the last read, which other documents the human is active on, and nudges. Zero arguments reads the open document. | Reading a document just to find one comment id — the ids are already in the last response's nudges. | `readOnlyHint: true`, `untrustedContentHint: true` |
| `add_comments` | Leaving one or more comments: on an exact quote, on a section, as a reply to an existing comment, or as a document-level note (also the way to say "looks ready to me"). Returns the created annotations with their resolved anchors. | Approving, requesting changes or submitting — the human does that from the page; say it in a note instead. Editing the human's comments. | none (mutating) |
| `update_comment` | Rewording a comment the agent created. | The human's comments (refused with `forbidden`). | none |
| `remove_comments` | Withdrawing comments the agent created, in batch. | The human's comments (refused). | `destructiveHint: true` (forward-compatible; ignored by today's dictionary) |
| `reveal` | Bringing the human's attention to a comment or a section by scrolling and selecting it — use right after leaving a comment you want them to see, or when answering "where is that". | Reading; it returns no content. | none |
| `nudge_user` | A short, transient message to the human in the page ("I've finished; two comments, nothing blocking, ready for your approval"). Not persisted, not part of the feedback. | Anything that should survive the session or be sent to the coding agent — use a document-level comment for that. | none |
| `list_documents` (folder sessions only) | Browsing the folder session's document tree when the nudges do not already name the document you need. | Reading document contents. | `readOnlyHint: true` |

Absent by design: `get_session`, `list_sections`, `list_annotations` (folded into `read_document`); `approve_plan`, `request_changes`, `send_feedback`, `approve`, `close_session` (human); `list_versions`/`show_version_diff` (a UI-driving verb with no comment value; the version outline is in `read_document.session.versions` for phase 1b if wanted); `open_file` (a read of a sibling is `read_document({ path })` and never navigates the human's UI).

### 3.3 Shapes

Envelope, identical for every tool:

```ts
type ToolResponse<T> =
  | { ok: true;  data: T;   nudges: Nudge[]; cursor?: string }
  | { ok: false; error: { code: "invalid_input" | "not_found" | "forbidden" | "not_available" | "conflict" | "failed"; message: string; hint?: string }; nudges: Nudge[] };

interface Nudge {
  code: NudgeCode;          // machine-readable, stable
  message: string;          // one sentence for the model
  ids?: string[];           // annotation ids this is about
  path?: string;            // document this is about (folder / linked-doc sessions)
  section?: string;         // heading slug this is about
  action?: { tool: string; args: Record<string, unknown> }; // the one call that acts on it
}
```

`read_document` input (every field optional; the empty call is the useful one):

```ts
{
  path?: string;        // folder / linked-doc sessions: a sibling document. Default: the open document.
  section?: string;     // heading slug from `outline`; returns only that section's text (annotations still complete).
  offset?: number;      // char offset into the (section) text, for large documents. Default 0.
  maxChars?: number;    // Default 16000. Text is cut at a block boundary; `cursor` carries the next offset.
  since?: string;       // watermark from a previous response; marks annotations newer than it as `isNew`.
                        // Default: the engine's own per-tab watermark, which advances on every read.
  include?: ("text" | "annotations" | "outline")[]; // Default all three.
}
```

`read_document` output (sketch, with a plan-review example):

```jsonc
{
  "ok": true,
  "cursor": "w:47",
  "data": {
    "session": {
      "mode": "plan",                       // plan | annotate | annotate-last | annotate-folder | annotate-app | review
      "surface": "markdown",                // markdown | html | live-app
      "source": { "title": "Add rate limiting to /api/upload", "path": null, "url": null },
      "gate": false, "readOnly": false,
      "decision": "pending",                // pending | approved | feedback-sent | exited  (informational; the human decides)
      "commentOnly": false,                 // true on html/live-app
      "sourceStale": false,                 // annotate: the file changed on disk since it was loaded
      "editing": false,                     // the human is in Edit Mode; text reflects their buffer
      "versions": { "current": 3, "total": 3 },
      "agentComments": 2, "humanComments": 5, "pendingUnsent": 7
    },
    "text": "# Add rate limiting…",          // windowed; see cursor
    "textRange": { "offset": 0, "length": 9120, "total": 9120, "truncated": false },
    "outline": [
      { "id": "goal", "level": 1, "title": "Goal", "line": 1, "annotations": 0 },
      { "id": "auth-changes", "level": 2, "title": "Auth changes", "line": 42, "annotations": 3 }
    ],
    "annotations": [
      {
        "id": "ann-9f2",
        "kind": "comment",                  // comment | deletion | note (document-level)
        "author": "ramos", "source": "human",   // human | browser-agent | <external tool name>
        "createdAt": "2026-08-25T18:02:11Z", "seq": 44, "isNew": true,
        "section": { "id": "auth-changes", "title": "Auth changes" },
        "quote": "rotate the signing key on every deploy",
        "context": "…we will rotate the signing key on every deploy so that…",   // ±120 chars
        "text": "This will invalidate every in-flight upload. Needs a grace window.",
        "inReplyTo": null, "replies": ["ann-a10"]
      }
    ],
    "otherDocuments": [                     // folder / linked-doc sessions only
      { "path": "docs/notes/rollout.md", "open": false, "annotations": 4, "newSinceLastRead": 2,
        "lastActivity": "2026-08-25T18:03:40Z", "composerOpen": false }
    ]
  },
  "nudges": [
    { "code": "annotations_new", "message": "The human added 3 comments since your last read.", "ids": ["ann-9f2","ann-9f3","ann-9f4"] },
    { "code": "composer_open", "message": "The human is typing a comment on 'Auth changes' right now; wait before commenting there.", "section": "auth-changes" },
    { "code": "other_document_active", "message": "The human is also annotating docs/notes/rollout.md (2 new comments).", "path": "docs/notes/rollout.md",
      "action": { "tool": "plannotator.read_document", "args": { "path": "docs/notes/rollout.md" } } }
  ]
}
```

`add_comments` input and output:

```ts
// input
{
  comments: Array<{
    text: string;                 // the comment. Markdown allowed (same renderer as the panel).
    quote?: string;               // exact text to anchor on. Resolved by the same text search share-restore uses.
    section?: string;             // heading slug; disambiguates a quote, or anchors a section-level comment when no quote.
    inReplyTo?: string;           // annotation id; the new comment inherits that anchor and threads under it.
    path?: string;                // folder / linked-doc sessions: a sibling document. Default: the open document.
    requestId?: string;           // idempotency key; a repeat returns the existing annotation, `deduplicated: true`.
  }>;   // 1..20
}
// output data
{
  results: Array<
    | { ok: true; annotation: AnnotationView; deduplicated?: boolean; anchoredBy: "quote" | "section" | "reply" | "document" }
    | { ok: false; index: number; error: { code: "not_found" | "ambiguous" | "forbidden" | "invalid_input"; message: string; candidates?: string[] } }
  >;
  created: number;
}
```

Anchoring rules, in order: `inReplyTo` (reuse the parent's anchor) → `quote` (+ `section` to disambiguate; two matches without a section → `ambiguous` with both contexts as `candidates`) → `section` alone (anchors on the heading block) → none (document-level note, the `GLOBAL_COMMENT` shape `Viewer.tsx:756-771`). On HTML and live surfaces only text-quote and document-level anchors exist; the response's `anchoredBy` says which was used. The created annotation is exactly what the human sees in the panel: `author` = the configured display name, `source: "browser-agent"`, stamped `pageUrl` on live.

`update_comment { id, text }` → `{ annotation }`. `remove_comments { ids }` → `{ results: [{ id, ok } | { id, ok: false, error }] }`. `reveal { annotationId? , section? , path? }` → `{ revealed: "annotation" | "section" }` (a `path` different from the open document opens it through the linked-doc path and says so in a nudge, because reveal *is* a request to move the human's view). `nudge_user { message }` (≤ 280 chars) → `{ shown: true }`; one banner at a time, a second call replaces it, and the banner offers "Show comments" when the agent has any. `list_documents { filter? }` → `{ documents: [{ path, title?, open, annotations, newSinceLastRead, lastActivity }] }`.

### 3.4 Nudge codes and their sources

All computed synchronously from state the page holds; none costs a fetch.

| Code | Fires when | Source in the page |
|---|---|---|
| `annotations_new` | annotations with `seq` > watermark exist (added or edited by anyone but the agent) | change tracker over `allAnnotations` (§4.4) |
| `annotations_removed` | ids the agent has seen are gone; if any were the agent's own: "the human removed your comment N" (this is the resolution signal) | change tracker tombstones |
| `replies_new` | new annotations whose `inReplyTo` is an agent comment | same, filtered |
| `composer_open` | the human has a comment composer open (markdown popover or HTML/live composer) | `useAnnotationHighlighter` popover state / `useHtmlAnnotation` `commentPopover` via the adapter |
| `source_stale` | the annotated file changed on disk since load | the existing source-watch subscription (`App.tsx:2705`), "refresh available" |
| `document_edited` | the human is in Edit Mode or the text differs from the loaded baseline | `isEditingMarkdown`, `editorDiffersFromBaseline` (`App.tsx:426`, `:438`) |
| `comment_only_surface` | first response on an HTML/live surface | `isHtmlSurface` |
| `page_changed` | live app: the human navigated to another in-app page since the last read | `livePageUrl` |
| `other_document_active` | folder/linked-doc: a sibling document has new annotations, an open composer, or was opened since the last read | linked-doc cache (`getDocAnnotations()`), `fileBrowser.activeFile`, per-path watermarks |
| `pending_unsent` | there are annotations and no decision yet — reminds the agent the human sends feedback, it does not | counts + `submitted` |
| `session_decided` | the human approved/sent/exited; write tools are now gone | `submitted` |
| `truncated` | text was windowed; carries the `cursor` | response builder |

### 3.5 Size heuristics

Plans are typically 3–15k characters; annotate targets and long RFCs run to 50k+. Chrome's 1.5k-per-output guidance is written for shopping carts; a review assistant that has to read the plan gets more value from one faithful window than from twenty tiny ones. Defaults: `maxChars` 16000 (whole document for almost every plan), cut at a block boundary, with `outline` always complete so a second call can target a section; `annotations` always complete up to 200 entries with `context` capped at ±120 chars and `text` at 1000 chars (beyond that, `truncated: true` on the entry and `update`/`reveal` still work by id); `otherDocuments` capped at 10, most recently active first, the rest reachable through `list_documents`. Code review (phase 2): `read_review` lists files with counts only; `read_file_diff` windows hunks at 24k chars.

### 3.6 Stable tool list with nudges, not a state-encoding tool list

Two ways to tell an agent "the document is stale": register a `refresh_document` tool only while stale, or keep the list fixed and put `source_stale` in the nudges. Recommendation: **fixed list within a surface, state in responses.** Reasons: (1) when a browser agent re-observes after `toolchange` is implementation-defined (`index.bs:1402-1406`) and many agent harnesses snapshot tools at conversation start, so a tool that appears mid-conversation may be invisible for a long time while a nudge lands on the very next call; (2) a tool that comes and goes forces the agent to reason about *why*, whereas a nudge says why; (3) a stable list is what the marketing docs and the header chip describe. The list changes only at hard capability boundaries where offering the tool would be a lie: write tools are absent on read-only archive and after the human's decision (`submitted`), `list_documents` exists only in folder sessions, and code-review tools exist only on the review surface. In practice that is one register/unregister transition per session, at decision time.

Hints: `readOnlyHint` on `read_document` and `list_documents` only. `untrustedContentHint` on `read_document` (the plan is agent-authored text; the diff is arbitrary code; comments may be external-tool text). `destructiveHint` is not in the WebMCP `ToolAnnotations` dictionary (`index.bs:1068-1071`) — only MCP has it — but WebIDL ignores unknown dictionary members, so setting `destructiveHint: true` on `remove_comments` costs nothing today and is honest the day #176 lands; note it in the engine with a comment so nobody "fixes" it away.

### 3.7 The five flows, before and after

"Before" counts the first draft of this document (`get_session`, `list_sections`, `read_document`, `list_annotations`, `add_comment`, `reveal`, decision tools). Payload sketches are abbreviated.

**(a) "What is going on in this page right now?"** Before: `get_session` → `list_sections` → `read_document` → `list_annotations` = **4 calls**. After: `read_document()` = **1 call**. The response above is the whole answer: mode, whether the human is mid-edit, the text, the outline with per-section comment counts, every comment with its quote and context, and the nudges.

**(b) "The user just annotated something — what do they want?"** Before: `list_annotations` → `read_document({ section })` for context = **2 calls**, and the agent had to diff ids itself. After: `read_document()` = **1 call**; the `annotations_new` nudge names the ids, each entry carries `isNew`, `quote`, `context` and `section`, and if the human is still typing, `composer_open` says to wait. In the common case the agent already learned this on its previous mutation's nudges and needs **0 extra calls**.

**(c) "Leave a comment on section X."** Before: `list_sections` → `read_document({ section })` → `add_comment` = **3 calls**. After: `add_comments({ comments: [{ section: "auth-changes", quote: "rotate the signing key", text: "…" }] })` = **1 call**; the response returns the annotation with its resolved `context`, so no read-back. If the agent has not read the section and wants an exact quote: `read_document({ section })` first = **2 calls**, the stated maximum.

**(d) "Reply to the user's comment."** Before: no reply model; `list_annotations` → `add_comment` on the same quote = **2 calls** and the two comments were unrelated in the panel. After: `add_comments({ comments: [{ inReplyTo: "ann-9f2", text: "Agreed — proposing a 10-minute grace window; see the note on 'Rollout'." }] })` = **1 call**; the id came from the nudge, the reply inherits the anchor, threads under the parent in the panel and the export (§4.5), and the response's nudges say whether the human added anything else meanwhile.

**(e) "The user is reviewing several files in a folder session."** Before: `list_files` → `open_file` (which moved the human's view) → `read_document` → `list_annotations`, per document = **4+ calls per document**, and no way to know which document mattered. After: the `other_document_active` nudge on any response names the document and the count, with the exact `action`; `read_document({ path: "docs/notes/rollout.md" })` = **1 call per document**, without navigating the human's UI; commenting there is `add_comments({ comments: [{ path, quote, text }] })` = **1 call**.

**(f, phase 2) "What changed in this review since I looked?"** `read_review()` = 1 call: files with `newAnnotations` counts and a `files_with_new_annotations` nudge; `read_file_diff({ path })` = 1 call returns the hunks and the comments on them with `isNew`.

### 3.8 Anti-patterns we are avoiding

- **Chatty list/get pairs** (`list_annotations` then `read_document`, `list_sections` then `read_document(section)`): one read carries the outline, the text and the annotations.
- **Mutations that need a read-back**: every mutation returns the created/updated objects and fresh nudges.
- **Silent state changes**: the human's new comments, removals of the agent's comments, an open composer, on-disk staleness, edit mode, page navigation, and sibling-document activity are all announced on the next response.
- **Tools that let the agent bypass the human**: none exists; the ownership rule keeps the human's comments out of the agent's reach too.
- **Tools that move the human's view as a side effect of reading**: `read_document({ path })` fetches; only `reveal` navigates, and says so.
- **State encoded in tool presence** (§3.6).
- **Descriptions that describe the UI instead of the job**: each description says what the tool is for, when not to use it, and what the response contains.

### 3.9 Phase-2 catalog (code review)

Same principles, seven tools: `read_review` (session + diff metadata + files with `+/-`, status, section, generated flag, `annotations`, `newAnnotations` + guide outline when active + nudges), `read_file_diff { path, offset?, maxChars? }` (hunks as unified text + the annotations on that file with `isNew`, line-anchored context), `add_comments` (items: `{ path, side, startLine, endLine?, text, suggestedCode?, inReplyTo?, requestId? }` or `{ path, text }` for file-scoped, or `{ text }` for the review-level note), `update_comment`, `remove_comments`, `reveal { annotationId? , path? , line? , guideSection? }`, `nudge_user`. No submit, no LGTM, no stage, no viewed, no diff switching, no agent-job launching, no PR platform submission. Nudge codes add `files_with_new_annotations`, `diff_stale` (the existing `useDiffFreshness` probe), `guide_section_changed` (the human moved to another Guided Review section). guides.show read-only: `read_review` and `reveal` only, if the viewer's budget allows the engine (§4.7).

---

## 4. Architecture

### 4.1 Placement, mirroring the shortcut system

The shortcut registry is the precedent: engine in `packages/ui/shortcuts/{core,runtime}.ts`, declarative scopes per surface, per-app composition in `packages/editor/shortcuts.ts` and `packages/review-editor/shortcuts.ts`. WebMCP gets the same shape:

```
packages/ui/webmcp/
  modelContext.ts      the ONLY file that spells document.modelContext; local structural
                       types (no declare global); resolveModelContext(doc) → ctx | null
  toolset.ts           ToolSpec, envelope + Nudge types, defineTool(), createToolRegistry(ctx)
                       (per-document singleton, reconcile-by-name, AbortController per tool)
  changes.ts           the change tracker: seq numbering, watermarks, tombstones, per-path
                       activity — pure, no DOM
  nudges.ts            buildNudges(adapterSnapshot, tracker, watermark) — pure
  useToolset.ts        React hook: attach a named toolset to the document registry;
                       handlers read through refs so re-renders never re-register
  policy.ts            seam: setWebMcpPolicy / resetWebMcpPolicy / getWebMcpPolicy
                       { enabled, namePrefix }
  index.ts
packages/editor/webmcp/
  documentTools.ts     buildDocumentTools(adapter: DocumentToolAdapter): ToolSpec[]
  folderTools.ts       buildFolderTools(adapter: FolderToolAdapter): ToolSpec[]
packages/review-editor/webmcp/
  ReviewToolProvider.tsx   <ReviewToolProvider/> mounted inside <ReviewStateProvider>
  reviewTools.ts           buildReviewTools(adapter): ToolSpec[]
```

Why `packages/ui` and not `packages/core`: the engine is React-adjacent (a hook) and ships to hosts through the existing `./hooks/*` / `./utils/*` wildcard exports (`packages/ui/package.json:16-18`) with no new export map entry; `core` needs manual `exports` entries and should stay pure. `changes.ts`, `nudges.ts` and the quote resolver are written without DOM so they can move to `core` later if the guide viewer wants them without React.

Why catalogs take an **adapter** rather than App state: `buildDocumentTools(adapter)` receives a narrow interface of getters and actions (`getSession()`, `getText()`, `getBlocks()`, `getAnnotations()`, `getOpenComposer()`, `getOtherDocuments()`, `addAnnotation(a)`, `updateAnnotation(id, patch)`, `removeAnnotation(id)`, `select(id)`, `showBanner(msg)`, `resolveQuote(quote, section)`). `App.tsx` builds the adapter once from refs — the `headerHandlersRef` pattern it already uses for stable access to always-current handlers (`App.tsx:4452-4477`) — and the catalogs never import from `App.tsx`. Catalogs and nudges are then unit-testable with a fake adapter and no DOM, and a host builds the same adapter over its own state.

### 4.2 Feature detection and the no-op contract

`resolveModelContext(document)` returns `null` when `typeof document === "undefined"`, when `document.modelContext` is absent, or when calling into it throws synchronously (the `clipboard.ts:73-86` house pattern: `typeof` for the environment, `?.` for the capability, `try/catch` for restricted contexts). Everything above it treats `null` as "no provider": `useToolset` returns without effects, the header chip is not rendered, and the settings toggle is hidden. Types are declared locally in `modelContext.ts` as a structural subset of `webmcp-types` (`registerTool`, `getTools`, `addEventListener`) and narrowed with one cast at that single site — the repo has no `declare global` and `packages/ui/globals.d.ts` is a published ambient file that must not augment `Document` for every consumer. `webmcp-types` is not added as a dependency: the surface we use is nine lines and the package is `0.1.x`.

When the API is absent, the module contributes one `typeof` check at mount and a hidden settings row. Bundle cost is a few KB in an already multi-MB single-file build.

### 4.3 Registration lifecycle

The registry is one object per `Document` (`WeakMap<Document, Registry>`), because registration is document-scoped and the name space is flat. It exposes `attach(setId, tools) → detach` and reconciles: a tool is registered when its name first appears in any attached set and unregistered (controller abort) when it disappears from all; a changed `description`/`inputSchema`/`annotations` for a live name is applied as abort-then-register (the spec's unregister/re-register race, `index.bs:419-450`, is acceptable because execute closures read through refs and a given name's schema never changes within a surface). Duplicate names across sets are skipped with a `console.warn` — never thrown, never replaced, because in a multi-document host that is the expected collision.

`useToolset({ id, tools, active })` recomputes `tools` only from state that changes membership — the surface (`plan`/`annotate`/`review`), `documentReadOnly`, `submitted`, folder-ness — memoized on those inputs; handlers live in a ref updated every render so a re-render never touches `registerTool`. Mount registers, unmount aborts every controller of the set; React StrictMode's double effect is safe because abort steps unregister synchronously (`index.bs:725-729`) before the second registration runs. `registerTool` rejections are caught and logged once per name, never rethrown.

Every `execute` is wrapped by the engine: input is checked against the declared JSON Schema with a small validator for the shapes we use (`object` with `properties`/`required`, `string` with `maxLength`, `integer` with `minimum`/`maximum`, `boolean`, `enum`, `array` with `minItems`/`maxItems`); the result is coerced into the envelope; thrown errors become `{ ok: false, error: { code: "failed" } }`; `nudges` are appended to **every** response, error responses included, by calling `buildNudges` after the handler ran (so a mutation's nudges reflect the mutation); the watermark advances after the response is built.

### 4.4 The change tracker (how "since your last read" works)

WebMCP page tools receive no caller identity (§1.2, service-worker explainer aside), and the spec's model is one agent per tab (`docs/service-workers.md:203-205`). So the watermark is **per tab, per page load**, held by the engine, and any agent that wants its own can pass `since` explicitly (every response returns `cursor`). Two agents on one tab would share the implicit watermark; that is a documented limitation, not a bug to engineer around.

Mechanics (`changes.ts`, pure): the adapter hands the tracker the current annotation list whenever it changes (the `allAnnotations` memo identity, `App.tsx:1665`, already changes only on real mutations; `useExternalAnnotations` events flow through it). The tracker keeps `{ id → { seq, hash } }` plus tombstones; a new id or a changed hash (text, quote, images) gets the next `seq`; a missing id gets a tombstone with the seq it vanished at and whether it was agent-authored. Cost: one O(n) pass per mutation over at most a few hundred entries. `isNew` = `seq > watermark`, excluding entries the agent itself created in this session (their ids are remembered from the mutation responses, so the agent's own comments are never "new to it"). Per-path activity for folder sessions uses the same tracker instance keyed by path over the linked-doc cache (`linkedDocHook.getDocAnnotations()` returns the per-document `CachedDocState` map, `useLinkedDoc.ts:150`), plus `fileBrowser.activeFile` for "open" and the composer state for "typing". `lastActivity` is the wall-clock time of the last seq change for that path.

The composer signal is the one adapter input that is not already lifted: `useAnnotationHighlighter` (markdown) and `useHtmlAnnotation` (HTML/live) each own their popover state; the adapter exposes `getOpenComposer(): { section?, quote? } | null` by reading a small ref both hooks already can set. No new persisted state anywhere.

### 4.5 Data-model touch: `inReplyTo`

Plannotator's `Annotation` (`packages/ui/types.ts`) is flat: no threads, no replies, no resolve state. Reply is the flow the maintainer asked for, and it is the cheapest way for an agent to be useful on the human's comments, so this design adds **one optional field**, `inReplyTo?: string`, to `Annotation` (and `CodeAnnotation` in phase 2), additive and browser-safe. A reply inherits its parent's anchor (same `blockId`/offsets/`originalText`; same `htmlAnchor` on HTML), the panel renders replies indented under the parent, and `exportAnnotations` groups a reply under its parent's entry so the coding agent reads the exchange in order. Nothing else changes: drafts, share links (the `ShareableAnnotation` tuples gain nothing; a reply shares as a plain comment on the same quote, which is the existing text-restore contract), and the servers (annotations are opaque arrays to them) are untouched. "Resolved" is deliberately not a state: the human deleting or editing the agent's comment is the signal, surfaced as `annotations_removed` / `annotations_new`. A first-class resolve state would be a product decision about the human UI, not an agent need.

### 4.6 Host seam (Workspaces)

One optional key on `configurePlannotatorUI`, following the `utils/upload.ts:39-56` shape exactly:

```ts
export interface WebMcpPolicy {
  /** Default: true when document.modelContext exists. */
  enabled?: boolean;
  /** Default: "plannotator." — hosts namespace their own tools. */
  namePrefix?: string;
}
```

There is no `confirm` seam: nothing in the catalog is consequential. Hosts reuse the engine, the tracker and the catalogs directly (`buildDocumentTools(adapter)` over their own document state, `useToolset` in their own root) and get the nudge vocabulary for free. Multi-document pages are the host's known hazard: the registry warns on duplicate names, and a host mounting several viewers should register one toolset whose `read_document`/`add_comments` take `path` (the folder-session shape already does exactly this). Documented in HANDOFF rather than solved speculatively in v1.

### 4.7 What touches the servers

**Nothing, in phase 1 and phase 2.** Every tool wraps an in-page handler; the HTML bundles are built once and copied into the Pi extension unchanged (`apps/pi-extension/package.json:55`), so both runtimes get it with no route change and `tests/parity/route-parity.test.ts` is unaffected. The settings toggle is a cookie-backed registry entry (`packages/ui/config/settings.ts`), which needs no `POST /api/config` allowlist change. `inReplyTo` rides inside the opaque annotation arrays the servers already store and forward. Reading a sibling document in a folder session goes through the existing `docPreviewFetcher` seam (`packages/ui/components/InlineMarkdown.tsx:18`), i.e. the same `/api/doc` the UI uses.

One optional, explicitly deferred server touch: sending `Origin-Agent-Cluster: ?1` on the HTML response of the three servers (and their Pi mirrors) would make the spec's origin-keyed precondition deterministic rather than a browser default. Chrome's default is origin-keyed and Plannotator never sets `document.domain`, so this is belt-and-braces. If a user reports `SecurityError` in the console on some engine, this is the fix.

guides.show: the read-only viewer does not import `configure.ts` (`apps/guides-show/viewer/main.tsx:26-29`), so the seam cannot enlarge its bundle; opting the viewer in is an explicit import of the engine and a `check:budgets` decision.

### 4.8 Testing strategy

Per the repo's rules (a test guards a regression you can name):

- **Engine, no DOM** (`toolset.test.ts`): a fake `ModelContext` is injected directly, so reconcile behavior runs under plain `bun test`: register on attach, abort on detach, duplicate-name skip with warning, StrictMode double-attach ends with one live registration, a throwing handler yields an envelope with nudges attached, `undefined` is never returned raw, output windowing emits `cursor`.
- **Change tracker, no DOM** (`changes.test.ts`): new id → new seq; edited text → new seq; removal → tombstone flagged agent-authored or not; the agent's own creations are never `isNew`; explicit `since` overrides the implicit watermark; per-path activity ordering.
- **Nudges, no DOM** (`nudges.test.ts`): table-driven over adapter snapshots — each nudge code fires for exactly its condition and carries the ids/path/action the flow relies on; no nudge fires on a quiet snapshot.
- **Catalogs, no DOM** (`documentTools.test.ts`, `folderTools.test.ts`, `reviewTools.test.ts`): fake adapters. Named for invariants: `add_comments` on an HTML surface never yields a DELETION; `update_comment`/`remove_comments` refuse a human-authored id with `forbidden`; `inReplyTo` inherits the parent anchor; ambiguous quote returns `candidates`; `requestId` repeat returns `deduplicated`; no tool name in any built set matches `/approve|deny|submit|send|close|stage|viewed/`; write tools are absent once `submitted` or read-only; every read tool carries `readOnlyHint`, `read_document` carries `untrustedContentHint`; names match `/^[A-Za-z0-9_.-]{1,128}$/`, descriptions ≤ 500 chars, parameter descriptions ≤ 150.
- **Hook, DOM** (`useToolset.seam.test.tsx`, `DOM_TESTS=1`, added to the explicit list at `.github/workflows/test.yml:81-152`): a fake `document.modelContext` installed with save/restore of the property descriptor in `beforeEach`/`afterEach` (the `skillCatalog.test.ts:14-40` idiom), mounted with `createRoot` + `act` like `useAIChat.seam.test.tsx`; mount registers, unmount aborts, a handler-identity change does not re-register. `configure.test.ts` gains the `webmcp` seam through its full `mock.module` ritual.
- **Export and panel** (`parser.test.ts` addition, one DOM test): a reply exports grouped under its parent; the panel renders it indented.
- **Security invariants, source-level** (the `live-proxy` suites' precedent): the bridge script contains no `modelContext` reference; `HtmlViewer.tsx` never emits an `allow` attribute containing `tools` on the srcdoc iframe; nothing under `components/html-viewer/*` imports the registry.
- **Manual smoke**: Chrome with `chrome://flags/#enable-webmcp-testing` and the Model Context Tool Inspector against `plannotator review`, `plannotator annotate <file>` and `plannotator annotate <folder>`; the five flows in §3.7 as a checklist in `tests/UI-TESTING.md`. Not CI.

---

## 5. Security and privacy analysis

The read-and-comment-only surface makes this section shorter than the first draft, and that is the point: there is no consequential tool, so there is no consent question, no confirmation dialog, no loop guard, and no way for a prompt-injected browser agent to approve a plan.

### 5.1 Impersonation by an annotated page

| Invariant | Mechanism | Pinned by |
|---|---|---|
| A srcdoc page cannot register tools | `sandbox="allow-scripts"`, no `allow` → opaque origin → `tools` policy `'self'` denied → `NotAllowedError` | Source-level test on the iframe attributes |
| A live app cannot register tools visible to the agent while framed (today) | Cross-origin by port, no `allow="tools"` | Same test; phase 3 revisits deliberately |
| Plannotator's provider never runs inside a frame it does not own | Provider mounted only in the editor/review roots; bridge script has no `modelContext` reference | Source-level test |
| Tool names cannot be squatted from a frame | Names are per-document; the browser attributes each tool to its origin (Advisement, `index.bs:1392`) | Spec; nothing to add |
| A page cannot reach a decision through a tool | No decision tool exists; the postMessage ingest clamp (`useHtmlAnnotation.ts:535-547`) is unchanged and orthogonal | Catalog name test |

The VS Code extension nests Plannotator in an iframe inside a webview (`apps/vscode-extension/src/panel-manager.ts:75`); there the document is not top-level and the `tools` feature is not delegated, so the provider no-ops. Correct, no code needed.

### 5.2 What a compromised browser agent can do

Worst case — the agent is fully prompt-injected by the plan text — it can: add comments (visible, attributed `browser-agent`, removable, never sent without the human), edit or remove its own comments, scroll the human's view (`reveal`), and show one transient banner (`nudge_user`, one at a time, replaced by the next, ≤ 280 chars, rendered as plain text). It cannot: touch the human's comments (ownership rule, `forbidden`), approve/deny/send/close, change settings, stage files, open URLs, or read anything the tab does not already display. Every content read is marked `untrustedContentHint` (`index.bs:1792-1798`) so the agent's own harness can spotlight the plan and diff text (`#output-injection-attacks`, `index.bs:1510-1579`). Tool descriptions and nudge messages are static strings we own; annotation text inside responses is data, never concatenated into a description or a nudge message.

### 5.3 Privacy: plan contents and the browser agent

Registering tools exposes nothing the agent cannot already observe — the spec's browser agent observes the whole tab, screenshots included (`index.bs:1348-1352`). Tools change convenience and fidelity, not reach. Still, the user should be able to say no and should see when tools are on:

- Setting `webmcpTools` (General tab; shown only when the API exists), default **on**: the API is present only in a browser the user chose for its agent, the agent acts on the user's prompt, and reads are already possible. The toggle is the opt-out.
- The header chip ("Tools · 6") makes the active state visible and lists what is registered, with descriptions.
- Remote sessions over plain HTTP (`http://<host>:19432`, `PLANNOTATOR_URL_HOST` display hosts included) are not secure contexts, so `document.modelContext` is absent and nothing registers. `--tailscale` sessions are HTTPS and would register; the tools are callable only by an agent in the browser that opened the page, the same exposure as the page itself. Note it in docs; no new hard-off.
- No tool returns file-system paths beyond what the UI shows (folder-session paths are the ones in the file browser), and no tool reads `serverConfig`, identity cookies, or AI provider configuration.
- Tool outputs stay in the browser; the provider posts nothing new to Plannotator's servers.

---

## 6. Phased plan

**Phase 1 — engine, tracker, plan review and every annotate surface (about 7–9 engineer-days).** `packages/ui/webmcp/*` (engine, change tracker, nudges, hook, policy seam), `packages/editor/webmcp/*` (document + folder catalogs and the adapter in `App.tsx`), the `inReplyTo` field with panel indent and export grouping, the composer-state ref, the header chip and the settings toggle, the `nudge_user` banner on the existing toast surface, tests and the CI list entries, HANDOFF/README sections, and a `docs/reference/webmcp-tools.md` page generated from the catalog builders (the keyboard-shortcuts page pattern, `apps/marketing/src/lib/shortcutReference.ts`). The extra days over the first draft go to the tracker and the folder-session activity model; the days saved come from deleting the decision tools and the confirmation seam. Release-note-worthy: "Plan review and annotate sessions expose read-and-comment WebMCP tools to browser-integrated agents (Chrome/Edge origin trial; enable `chrome://flags/#enable-webmcp-testing` locally). Agents can read the document with all annotations in one call, reply to your comments, and nudge you — approving and sending feedback stay yours. Opt out in Settings → General." Also release-note-worthy on its own: threaded replies in the annotation panel.

**Phase 2 — code review, then guides.show (about 4–5 days).** `<ReviewToolProvider/>` and `reviewTools.ts` over `ReviewState`; `inReplyTo` on `CodeAnnotation`; the diff-freshness and guide-section nudges; the viewer's `file://` verification if the budget allows. Release-note-worthy: "Code review tools: read the review and any file's diff with its comments in one call, comment on lines with suggestions, reply, reveal."

**Phase 3 — consumer side, enumeration only (about 5 days plus a policy decision).** Bridge-side `getTools()` + `toolchange` relay over the tokenized channel, a "Tools this page offers" panel in live-app sessions rendering descriptors as untrusted text, the same list in `read_document.session.pageTools`, and `add_comments` accepting `{ tool: name }` as an anchor. Requires deciding to add `allow="tools"` to the live-app iframe and re-running the live-annotate smoke loop. Release-note-worthy: "Review a WebMCP integration: see and annotate a running app's registered tools."

Not planned: decision or submission tools of any kind, declarative form tools, executing the annotated app's tools, diff switching or agent-job launching from a browser agent, a first-class "resolved" state.

---

## 7. Open questions and risks

1. **Spec instability.** Names and signatures have moved repeatedly (fact 2). Insulation: `modelContext.ts` is the only file that names `document.modelContext`, `registerTool`, `toolchange`, or the annotation keys; a rename is a one-file change plus its test. `webmcp-types` is not a dependency.
2. **Error plumbing is a bare `UnknownError`.** Mitigated by the envelope with nudges on errors too.
3. **Watermark identity.** Page tools carry no caller identity, so the implicit watermark is per tab; `since` is the escape hatch. If the spec adds a session id (the service-worker explainer's `clientInfo`), the tracker keys on it in one place.
4. **Origin trial + random ports.** Chrome-stable users need the flag until the feature ships; agent-embedded browsers do not. Docs must say so.
5. **Origin-keyed precondition on non-Chromium engines.** Unknown until they implement; the deferred `Origin-Agent-Cluster: ?1` header is the fix.
6. **Multi-document hosts.** Flat name space with duplicate warnings; `path`-taking tools are the recommended host shape.
7. **Output budgets vs. real documents.** 16k-char windows exceed Chrome's guidance by design; the outline and `cursor` keep large documents navigable. Revisit with real agent transcripts.
8. **Quote anchoring on HTML surfaces.** Only text-quote and document-level anchors are creatable by tools (the share-link restore contract, `sharing.multiTarget.test.ts`); element-anchored and multi-target comments stay human-only. Documented.
9. **`inReplyTo` is a data-model change**, small but visible in the panel and the export; it needs a product look at the indent and the export grouping before phase 1 ships.
10. **guides.show `file://` behavior** is untested; verify before claiming it in phase 2.
11. **The "tools in iframes are not exposed to the built-in agent" direction** (README `:470`) is favorable but unresolved; if it resolves the other way, phase 3's `allow="tools"` decision needs a matching UI telling the reviewer the app's tools are visible to their browser agent too.

---

## 8. Recommendation

Build the provider as a read-and-comment surface in the shape of the shortcut system: a small feature-detected engine in `packages/ui/webmcp/` with a per-tab change tracker, adapter-driven catalogs per app, one `webmcp` policy seam, and zero server changes. Six tools in phase 1 — `read_document`, `add_comments`, `update_comment`, `remove_comments`, `reveal`, `nudge_user` (plus `list_documents` in folder sessions) — where the zero-argument `read_document` is the whole situation in one call, every mutation returns what it made, and every response carries nudges about the human's new comments, open composer, sibling documents, staleness and edits. No tool decides anything; when the agent thinks the plan is ready it leaves a note or nudges the human, and the human clicks. That single rule deletes the consent problem the spec has not solved, keeps the annotate iframes exactly as sandboxed as they are today, and makes the catalog small enough that an agent can hold it in mind. A browser without WebMCP sees one `typeof` check and nothing else.
