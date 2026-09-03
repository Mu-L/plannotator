# Design: one document app (plan and annotate unification), submission resilience, and the OpenCode delivery chain

Status: proposal, no implementation. Investigated 2026-08-26 against the current main checkout (v0.27.8). All file references are to the working tree. Source: GitHub issue #1392 plus an independent re-verification of the prior investigation.

The ruling this design is organized around: plan review and annotate are literally the same app. Treating them as different apps was the mistake. Every finding below that was previously read as "an annotate-mode bug" is re-read here as "a place where the one app was forked by a `mode` check", and the fix is to remove the fork, not to add an annotate branch beside the plan branch. Where a capability genuinely cannot apply to a surface, it is named as a justified exception with the reason.

Two other threads from #1392 are handled in the same doc because they share a root: work that lives only in one browser tab is lost when the process behind it dies. That is a surface-independent failure, so the fix is a surface-independent layer.

---

## 1. Vet results

Each item: verdict, then the receipts. "Confirmed" means the claim holds at the cited lines today. "Partly" means the mechanism holds but the framing or a line number was off.

### A. Settings tab gating: CONFIRMED, plus a bigger gap than reported

- `Settings` takes `mode?: 'plan' | 'annotate' | 'review'` (`packages/ui/components/Settings.tsx:87`) defaulting to `'plan'` (`:856`). The main tab list pushes Display, Saving, Labels only `if (mode === 'plan')` (`:926-930`) and Hooks only `if (mode === 'plan')` (`:944-946`); the integration list adds Obsidian, Bear, Octarine only for `mode === 'plan'` (`:950-955`). Annotate therefore sees General, Theme, Vim, Shortcuts, Files: exactly the five tabs the reporter listed first.
- The editor's single `<Settings` call passes `mode={annotateMode ? 'annotate' : 'plan'}` (`packages/editor/components/AppHeader.tsx:471`); `annotateMode` is set for `annotate`, `annotate-last`, `annotate-folder`, `annotate-app` (`packages/editor/App.tsx:2929-2930`). URL sessions arrive as `annotate`.
- Notes saving works on the annotate server: `POST /api/save-notes` is routed at `packages/server/annotate.ts:1146-1148` to `handleSaveNotes` (`packages/server/shared-handlers.ts:300-333`), mirrored on Pi (`apps/pi-extension/server/serverAnnotate.ts:1038-1039`). Settings are cookies (`packages/ui/utils/storage.ts:23-43`), so a vault configured in a plan session is readable in an annotate session on any port (`packages/ui/utils/obsidian.ts:49-60`).
- The Notes tab is ungated by mode (`packages/ui/components/ExportModal.tsx:117`, `isApiMode && !!markdown`). MISSED by the investigation: that `!!markdown` gate means raw-HTML, live-app, and unpicked-folder annotate sessions have no Notes tab at all, because those set `markdown` to `''` (`App.tsx:2900`, `:2913`, `:2916`). "End to end" holds only for markdown-file annotate.
- Copy: `ExportModal.tsx:439`, `:479`, `:524` say "Enable in Settings > Saving > Obsidian" (Bear, Octarine). In plan mode the Saving tab carries an Integrations jump list (`Settings.tsx:1786-1804`) so the copy is loosely navigable there; in annotate mode both named tabs are absent, so the hint is a dead pointer exactly where the reporter hit it.
- Doc: `apps/marketing/src/content/docs/getting-started/ui-settings.md:84-117` nests Obsidian and Bear under "Saving" and omits Octarine, Labels, Hooks, Vim, Files.
- "Tabs appeared later": the async-race hypothesis is REFUTED (the app renders a blank viewport until `/api/plan` settles, `App.tsx:5080-5086`, and `annotateMode` is set inside the same `.then()` that clears `isLoading`, `:3010`). The surface hypothesis is CONFIRMED: archive sessions (`App.tsx:2889-2895`) and shared sessions (`:2864-2865`) never set `annotateMode`, so the header passes `'plan'` and every plan tab shows. The reporter almost certainly opened a plan-review or share/archive surface between the two screenshots.
- Same class, missed: `origin === 'claude-code' && mode === 'plan'` gates the permission-mode section (`Settings.tsx:1325`); the Saving tab's Default Save Action (`:1775-1781`) is plan-only, so annotate users cannot set a default notes app even on sessions where Notes works.

### B1. OpenCode launch path: CONFIRMED (one line-number correction, one version caveat)

- The V1 plugin awaits the whole review inside OpenCode's process: `command.execute.before` (`apps/opencode-plugin/index.ts:448-454`), `await handleCliCommand(...)` (`:509-516`), and the embedded handlers block on `await server.waitForDecision()` (`apps/opencode-plugin/commands.ts:395-396`, also `:172`, `:512`). No shell tool is involved, so the plugin path cannot be what "immediately closes".
- The skill path: `scripts/install.sh:1753-1758` installs the core skills into `~/.agents/skills` (line 1357 is only the variable). OpenCode scans `.agents/skills/**/SKILL.md` (`~/oss-agents/opencode/packages/opencode/src/skill/index.ts:22-23`, `:186-193`) and registers each skill as a slash command unless a config command already owns the name (`packages/opencode/src/command/index.ts:134-146`). Version caveat: the checkout is 1.18.18 and the feature landed in commit `81ac41e089` (2026-01-31); "1.18" as a threshold is not verifiable from this checkout.
- Shell timeout and group kill: default 120s (`packages/opencode/src/tool/shell.ts:347`, applied at `:618`); on timeout `handle.kill({ forceKillAfter: "3 seconds" })` (`:540-554`), which sends SIGTERM to the process group (`packages/core/src/cross-spawn-spawner.ts:306-308`, `:427-436`) because children spawn `detached` on non-Windows (`:378`).
- Plannotator on SIGTERM: `process.once("SIGTERM", () => process.exit(143))` (`apps/hook/server/index.ts:492`); exit handlers only unregister the session and tear down worktrees or tailscale (`:477`, `packages/server/review.ts:3457`, `packages/server/tailscale-serve.ts:129`). Nothing writes a decision or submission record. Nuance the investigation understated: annotations already saved by the client's incremental `POST /api/draft` survive the kill; what is lost is the live session and any decision.
- Only `apps/skills/core/plannotator/SKILL.md:30` mentions the timeout; the three lightweight skills do not, and all three carry `disable-model-invocation: true` so they are exactly the ones a user's slash command runs.

### B2. Installer prints the plugin entry; empty stub: CONFIRMED, mechanism corrected

- `scripts/install.sh:1992-2003` prints `"plugin": ["@plannotator/opencode@latest"]` and never writes `opencode.json`. It does write the command stubs to `~/.config/opencode/commands` (`:1615`, `:1763-1768`) and clears the plugin cache (`:1308`).
- `apps/opencode-plugin/commands/plannotator-annotate.md` is frontmatter only. Config commands are loaded from `{command,commands}/**/*.md` (`packages/opencode/src/config/command.ts:15`) and shadow the skill command of the same name (`command/index.ts:134-135`).
- Empty execution: with no arguments the template is an empty text part, dropped at `packages/opencode/src/session/message-v2.ts:206` and `:241`, while `prompt()` still runs (`session/prompt.ts:1466`): invisible message, burned call. CORRECTION: with arguments (`/plannotator-annotate notes.md`) `prompt.ts:1392-1394` appends the raw arguments to the empty template and `resolvePromptParts` auto-attaches an existing file path as a FilePart. The realistic unconfigured-plugin failure is therefore "bare filename sent to the model with the whole file attached", the #713 context-blowout class the plugin comment at `apps/opencode-plugin/index.ts:438-443` warns about, not merely an invisible message.

### B3. Package exports: CONFIRMED fields, overstated consequence, #1196 mislabeled

- `apps/opencode-plugin/package.json`: `"main": "dist/index.js"`, `"exports": { ".": "./dist/server.js" }`, with the maintainer's comment explaining OpenCode 1 loads `main` and OpenCode 2 loads `exports["."]`. `server.ts` registers only `submit_plan` (`:138-142`) and a context hook (`:80`); no command interception.
- OpenCode 1.18's loader checks `exports["./server"]` then falls back to `main` and never reads `exports["."]` (`packages/opencode/src/plugin/shared.ts:103-113`). So "any exports-honouring resolver loads the V2 adapter" is overstated for the runtime the reporter is on; the exposure is OpenCode 2, whose loader is not in this checkout.
- `#1196` is an open ISSUE ("move V2 adapter to the stable plugin API"), not a PR, and does not mention command interception. The V2 adapter PR was #1194.

### B4. Silent submit failure: CONFIRMED, and worse on review

- `handleAnnotateFeedback` gates on `res.ok` (`packages/editor/App.tsx:3499`) but the catch is `setIsSubmitting(false); scheduleDraftSaveAfterSubmitFailure();` (`:3502-3505`) with no user-visible signal, in a file that imports sonner (`:2`) and calls `toast.error` seventeen lines earlier (`:3485`). `handleAnnotateApprove` has the identical silent catch (`:3535-3541`).
- The "recovery" is `setTimeout(() => scheduleDraftSave(), 0)` (`packages/ui/hooks/useAnnotationDraft.ts:452-456`), whose transport swallows every error (`:432-438`, "silent failure, draft is best-effort"). Against a dead server it is a no-op.
- Plan `handleApprove` (`App.tsx:3398-3403`) and `handleDeny` (`:3418-3433`) call `setSubmitted(...)` without checking `res.ok`; a 5xx shows the success overlay.
- Review editor (`packages/review-editor/App.tsx:3142-3163`, `:3186-3207`) checks `res.ok` and sets `setCopyFeedback('Failed to send')` (`:3160`, `:3203`), but `copyFeedback` is only ever compared against `'Feedback copied!'` (`:3511`, `:3958`), so the error state renders as the default button. Dead code: no surface in the product shows a visible submit failure.

### B5. Draft identity: CONFIRMED

- `draftKey = contentHash(draftSource)` where single-file and annotate-last fall to the content branch (`packages/server/annotate.ts:343-349`); live-app keys on `liveAppDraftIdentity(targetUrl)`, folder on `folder:<resolved path>`. Pi is identical (`apps/pi-extension/server/serverAnnotate.ts:315-321`). History is keyed by path (`packages/shared/annotate-history.ts:51-59`, header comment `:10-13`).
- No pruning: `packages/shared/draft.ts` removes files only in `deleteDraft` (`:149`) and `clearTombstone` (`:85`); no sweep exists in `packages/shared`, `packages/server`, or the Pi server. MISSED: `deleteDraft` with a generation writes a `.deleted.json` tombstone (`:77-80`, `:150`) that is also never swept, so even clean submissions leave a file per content hash.

### B6. #678 submission record scope: CONFIRMED

- `singleFileLocalAnnotate = mode === "annotate" && !/^https?:\/\//i.test(filePath)` (`packages/server/annotate.ts:297`); `persistSubmittedDecision` returns early otherwise (`:387-388`), called on `/api/approve` (`:1096`) and `/api/feedback` (`:1127`). Pi mirrors it (`serverAnnotate.ts:338-339`, `:400-412`). Plan mode has only the `plans/` decision snapshot (`packages/server/index.ts:529-534`, `:570-575`, gated on `planSaveEnabled`). Review persists nothing on feedback (`packages/server/review.ts:3285-3303`).

### B7. cli-bridge detach: CONFIRMED

- `detached = abortSignal !== undefined && process.platform !== "win32"` (`apps/opencode-plugin/cli-bridge.ts:346-347`), spawned with piped stdio (`:379-385`). `handleCliCommand`'s input type has no `abortSignal` (`:624-631`) and its three `runPlannotatorCli` calls pass none (`:636`, `:679`, `:721`); only `submit_plan` passes one (`index.ts:542`, `:555`). "Writes into a broken pipe" is inference from piped stdio to a dead parent, not asserted in code. Same class: cli-bridge's own SIGKILL escalation is 1s (`:368-374`), tighter than OpenCode's 3s.

### C. Feature ask: CONFIRMED as framed

- Every save-notes body is `{ plan: markdown }` (`ExportModal.tsx:166`, `:172`, `:176`; auto-save `App.tsx:3087-3115`); the integrations write only `plan` (`packages/server/integrations.ts:100`, `:135`, `:144`, `:163-168`, `:191-203`).
- Arrival auto-save is disabled for annotate, shared, and archive (`App.tsx:3077`).
- Something close already exists but only for plan decisions: `saveFinalSnapshot` appends the exported annotations after a `---` (`packages/shared/storage.ts:96-99`) into `~/.plannotator/plans/`, and `saveAnnotations` writes `{slug}.annotations.md` (`:73-79`). The notes integrations never receive that text.

### Severity ranking

| Rank | Item | Class | Disposition |
|---|---|---|---|
| 1 | B4 silent submit failure, all three surfaces, plus the plan `res.ok` gap | data loss with no signal | fix now |
| 2 | A settings fork (tabs, Default Save Action, Notes tab on HTML surfaces, copy, doc) | the one-app mistake, user-visible | fix now |
| 3 | B7 undetached CLI child | data loss on abandoned review | fix now (one line) |
| 4 | B2 empty stub / installer does not write plugin entry | first-run failure, burned calls, context blowout | fix now (stub), follow-up (installer write) |
| 5 | B1 skill timeout guidance | data loss on the skill path | fix now (docs), follow-up (SIGTERM behavior) |
| 6 | B5 draft identity and pruning | orphaned recovery data | follow-up |
| 7 | B6 submission record scope | recovery gap on other surfaces | folds into the resilience layer |
| 8 | B3 V2 adapter lacks interception | future breakage (OpenCode 2) | follow-up, blocks #1196 |
| 9 | C notes payload and auto-save | feature | phase 3 |
| 10 | Reporter's actual launch path and the Codex observation | unknown | needs reporter input |

---

## 2. The one-app principle applied

### 2.1 What "same app" means in code

The editor already is one app: one `App.tsx`, one `/api/plan` shape (mode is a field on the payload, `App.tsx:2889-2930`), one draft hook, one export modal, one settings component, one header. The forks are small and enumerable, and they are all `mode`-shaped predicates rather than capability-shaped ones:

- `Settings` gates on `mode === 'plan'` (`Settings.tsx:926-955`, `:1325`).
- `AppHeader` collapses four session kinds into a two-valued prop (`AppHeader.tsx:471`).
- Auto-save gates on `annotateMode` (`App.tsx:3077`).
- The server writes a durable submission record only for one session kind (`annotate.ts:297`).
- The Notes tab keys on `!!markdown`, a proxy for "this surface has a document", which fails for HTML surfaces that do have one (`ExportModal.tsx:117`).

The rule this design adopts: a document surface asks "what can this session do" (a capability the server advertises or the client derives), never "which subcommand launched me". `mode` remains a field on the payload for the few places that legitimately need it, and it stops being a prop that UI components branch on.

### 2.2 Justified exceptions

These are the only places a plan/annotate distinction survives, each with the reason it cannot be unified:

| Capability | Why it is decision-flow-specific | Where it is gated today |
|---|---|---|
| Approve / Deny with `hookSpecificOutput` | The plan hook's contract is an allow/deny decision returned to the caller; annotate returns feedback or approval without a deny. | `/api/approve`, `/api/deny` vs annotate `/api/feedback`, `/api/approve`, `/api/exit` |
| Agent switch on approve | OpenCode-only decision-flow option that names the agent that executes the approved plan. | `packages/ui/utils/agentSwitch.ts`, approve body |
| Claude Code permission-mode preservation | Applies only to the `ExitPlanMode` hook flow. | `Settings.tsx:1325` |
| Plan decision snapshots (`planSave`) | Snapshots are "approved"/"denied" records in `~/.plannotator/plans/`; annotate has no decision to snapshot. | `packages/server/index.ts:529-534` |
| Plan version diff from resubmission | Annotate has the same machinery keyed by file path, so this is already unified; listed only to note that it is not an exception. | `annotate-history.ts:51-59` |
| Annotate agent terminal | A session capability (`agentTerminalAvailable`), not a mode; already gated correctly on availability. Keep. | `Settings.tsx:1446` |

Everything else in Settings (Display, Saving minus the plan-snapshot section, Labels, Hooks visibility, Obsidian, Bear, Octarine, Default Save Action) applies to any document surface. Hooks visibility deserves a one-line check during implementation: if the tab only concerns Claude Code hook events, it belongs with the permission-mode exception; if it is generic hook-output visibility, it is a document setting.

---

## 3. Settings unification

### 3.1 Tab set by surface

| Tab | Document app (plan, annotate, all flavours) | Read-only document (archive, shared) | Review |
|---|---|---|---|
| General | yes | yes | yes |
| Theme | yes | yes | yes |
| Display | yes | yes | Editor (review's own) |
| Saving | yes; plan-snapshot section shown only when the session advertises a decision flow | yes, with server-backed controls disabled and a one-line reason | no |
| Labels | yes | yes | no |
| Vim | yes | yes | no |
| Shortcuts | yes | yes | yes |
| Hooks | pending the check in 2.2 | same | no |
| Git, Analysis, Comments, AI | no | no | yes |
| Integrations: Files | yes | yes | yes |
| Integrations: Obsidian, Bear, Octarine | yes | yes (configurable; saving needs an API session) | no |

Review stays a distinct app with its own tab set; that is a real product boundary (code review over a VCS), not the plan/annotate fork. Read-only surfaces show the full document tab set because settings are cookies shared across all sessions (`storage.ts:2-8`): the reporter could configure Obsidian from an archive view and have it apply to the next annotate session. Controls that need a live API session (Default Save Action's "save now") are disabled with a reason, not hidden.

### 3.2 The `mode` prop

`Settings` currently accepts `'plan' | 'annotate' | 'review'` (`Settings.tsx:87`). Proposal: collapse to `surface: 'document' | 'review'` plus an explicit `capabilities` object for the exceptions in 2.2 (`{ decisionFlow: boolean; permissionMode: boolean; agentTerminal: boolean; readOnly: boolean }`). Under the `packages/ui` seam rules this is an additive seam: keep `mode` accepted for one release, mapping `'plan'` to `{ surface: 'document', decisionFlow: true }` and `'annotate'` to `{ surface: 'document', decisionFlow: false }`, so the Workspaces host is not broken. `AppHeader.tsx:471` then passes the derived capabilities instead of `annotateMode ? 'annotate' : 'plan'`, and the default at `Settings.tsx:856` becomes the document surface with `decisionFlow: false`, so a host that omits everything gets the safe superset rather than plan-only extras.

### 3.3 Notes tab and copy

- `ExportModal.tsx:117` should key on "this session has a document to save" rather than `!!markdown`: for raw-HTML sessions the save payload is the source markdown when `--markdown` was used and otherwise the HTML file's own path or content; for live-app sessions there is nothing to save and the tab is hidden with a reason. This is the same capability-not-mode rule.
- The three "Enable in Settings > Saving > Obsidian" strings (`:439`, `:479`, `:524`) become a button that opens Settings directly on the named integration tab (the editor already owns both dialogs), so the copy can never name a tab that does not exist. If a text hint is kept, it reads "Enable in Settings > Integrations > Obsidian".
- `ui-settings.md:84-117` is rewritten from the tab list in 3.1, including Octarine, Labels, Hooks, Vim, Files, and the sentence that the tab set is identical for plan and annotate.

### 3.4 Auto-save

`App.tsx:3077` excludes annotate. Arrival auto-save was designed for plans (a plan arrives, gets filed); auto-filing every annotated file into a vault on open is not what an annotate user wants. The unification is not "lift the gate" but "make the setting mean the same thing on both": the Saving tab's auto-save option gains an explicit trigger choice, `on arrival` (plan default, available on any surface) or `on submit` (see 6), and the surface no longer decides.

---

## 4. Submission resilience as a surface-independent layer

### 4.1 Requirements

1. A failed submission is always visible, on every surface, and never closes the window or shows a success overlay.
2. The composed feedback is never trapped in React state: the user can retrieve it without the server.
3. Recovery composes with what exists: server-side drafts (`/api/draft`), the #678 submission record, the plan decision snapshot.
4. One implementation, three call sites (plan approve/deny, annotate feedback/approve, review feedback/approve), both runtimes untouched except where a new endpoint is named.

### 4.2 Shape

A `submitDecision` helper in `packages/ui` (new seam, additive) wrapping `fetch`:

- Checks `res.ok` and treats a network error and a non-2xx alike as `{ delivered: false, reason }`. This fixes `App.tsx:3398-3403`, `:3418-3433`, and makes the review editor's `:3160` path real by replacing the dead `copyFeedback` string with a toast.
- On failure: `toast.error` with the reason, `setIsSubmitting(false)`, and the outbox step below. The window never closes and the success overlay never shows. The draft "recovery" at `useAnnotationDraft.ts:452-456` stays (it is correct when the server is alive and the failure was transient), but it is no longer the only recovery.
- On success: unchanged.

The outbox: before the request is sent, the full submission payload (decision kind, feedback text, exported annotations text, attachments by path) is written to `localStorage` under the session's draft key; it is removed on `delivered: true`. On failure a recovery sheet opens with the composed feedback as text and three actions: Copy, Download as `.md`, Retry. The sheet is the load-bearing part, not the storage.

Honest limits of browser-side storage here, so nobody over-promises in release notes: `localStorage` is per origin and the origin includes the port, so a local session on a random port cannot read an outbox written by a previous session on another port. Automatic cross-session recovery from the outbox therefore works only where the port is fixed (remote mode's `19432`, `--tailscale`, VS Code's proxy) and for a same-tab reload. Cookies are host-scoped and cross-port, which is why settings use them (`storage.ts:2-8`), but they are capped at about 4 KB and cannot hold feedback. The design accepts this: the sheet gives the user the text in hand immediately, and the server-side draft (already saved incrementally) plus the path-keyed draft identity in 5 restore annotations on reopen. A tiny cookie flag (`plannotator-outbox-pending=<draftKey>`) lets the next session on any port say "an undelivered submission for this document exists in another tab or in the file you downloaded" rather than staying silent.

### 4.3 Server side, both runtimes

- Widen the #678 record from `singleFileLocalAnnotate` (`annotate.ts:297`) to every document session that has a stable identity: single file, folder (per file), URL, annotate-last, and plan. Live-app sessions stay stateless by the same reasoning that keeps them off history. This is one predicate change in `persistSubmittedDecision` plus the Pi mirror (`serverAnnotate.ts:338-339`, `:400-412`), and the plan server gains the same call beside `saveFinalSnapshot` (`index.ts:529-534`) so a record exists even when `planSave` is off. Review feedback gets a record too (`review.ts:3285-3303`), keyed on the review cwd and diff fingerprint, so review is no longer the one surface with nothing durable.
- A session-ended signal. When the CLI receives SIGTERM (`apps/hook/server/index.ts:492`) it should, before exiting, push a `session-ended` event on the SSE stream the client already holds (the external-annotations stream is present on all three servers) so the UI flips to "agent disconnected; your work is saved as a draft; use Copy or Download to hand it over" instead of discovering the death on the next click. This is a small handler on each runtime plus a client listener; it does not keep the server alive.

### 4.4 Tests

Per the Testing Rules, the tests that earn their place: a `submitDecision` unit test that a non-2xx returns `delivered: false` (guards the plan `res.ok` regression); an outbox test that a failed submit leaves the payload retrievable and a successful one removes it; a server test that the submission record is written for a URL and a plan session (guards the predicate widening on both runtimes). No copy pinning on the sheet.

---

## 5. Draft identity

### 5.1 Path-keyed, matching history

Today the draft key is a content hash (`annotate.ts:343-349`) while history is path-keyed (`annotate-history.ts:51-59`). Agents editing the file between sessions is the normal case, so the content key orphans exactly the drafts a user most needs. Proposal: the draft key becomes `contentHash` of a stable identity string, chosen per session kind:

| Session | Identity | Note |
|---|---|---|
| single file (md, txt, html, config) | `file:<resolved path>` | same input as the history slug |
| folder | `folder:<resolved folder>` plus per-file entries `file:<resolved path>` | unchanged for the folder envelope; per-file drafts get their own key so a folder session and a later single-file session on the same file share a draft |
| URL | `url:<normalized URL>` | today a content hash of the converted page, which changes on every fetch |
| annotate-last | content hash of the message | content IS the identity; unchanged |
| live-app | `liveAppDraftIdentity(targetUrl)` | unchanged |
| plan | current slug-based key | out of scope for this change; verify it is path-stable during implementation |

The identity string and the per-kind rule live in `packages/core` (browser-safe, pure) so both runtimes and any host derive the same key; the two servers only call it.

### 5.2 Restoring onto changed content

A path-keyed draft can be restored onto a file whose text has changed. Restore is already text-search based (the existing "restore or dismiss" banner the reporter describes); the requirement added here is that annotations whose text no longer resolves are kept and listed as unplaced in the annotations panel rather than dropped, so a user can re-anchor or delete them deliberately. The version diff (previous vs current, already available on annotate) is the natural place to show why they failed.

### 5.3 Migration and pruning

- Migration: for one release the server loads by the new key, falls back to the content key, and on a fallback hit re-saves under the new key and deletes the old file. No user action.
- Pruning: `packages/shared/draft.ts` gains `pruneDrafts(dir, maxAgeDays)` that removes draft files and `.deleted.json` tombstones (`draft.ts:77-80`, `:150`) older than the threshold by mtime, run once at server start on both runtimes. Default 30 days; drafts are recovery data, not history. `PLANNOTATOR_ANNOTATE_HISTORY=0` does not affect drafts today and should not start to.

---

## 6. The feature ask, scoped honestly

"Save notes automatically, ideally alongside or inside the plan." Three distinct asks are folded into that sentence:

1. Notes payload with annotations. Falls out of the unification. `/api/save-notes` gains an optional `annotations` string (the same `exportAnnotations` text plan decisions already append after `---`, `storage.ts:96-99`), the three integrations append it the same way, and the Notes tab and auto-save send it when the user has annotations. Both runtimes, one shared handler (`shared-handlers.ts:300-333`) plus the Pi route.
2. Auto-save on submit. The `on submit` trigger from 3.4: when a decision is delivered (or lands in the outbox), the notes save fires with plan plus annotations. This is the "very simple persistence option" the reporter asks for, and it works on plan and annotate alike.
3. Writing feedback into the source document itself. This is a different feature: it touches Edit Mode's source-save allowlist (`SOURCE_SAVE_FILE_REGEX`, `packages/core/source-save.ts`), the agent's view of the file, and the version history. It deserves its own design, and it should wait for the reporter to say whether "inside the plan" means an appended section, frontmatter, or a sidecar. Recommendation: not in scope here.

---

## 7. The OpenCode delivery chain

### 7.1 Installer writes the plugin entry

Precedent: the Gemini path merges a hook into `~/.gemini/settings.json` with node, leaves an existing integration untouched, and prints the snippet when node is absent (`scripts/install.sh:1906-1942`). The OpenCode path should do the same for `~/.config/opencode/opencode.json` (OpenCode reads `opencode.json` then `opencode.jsonc` from its config dir, `packages/opencode/src/config/config.ts:259-260`):

- If `opencode.json` exists and already lists `@plannotator/opencode`, say so and leave it.
- If it exists without the entry, merge `plugin: [..., "@plannotator/opencode@latest"]` with node, preserving other keys; if only `opencode.jsonc` exists, print the snippet (comments make a JSON merge unsafe).
- If neither exists, write a minimal `{ "$schema": "https://opencode.ai/config.json", "plugin": ["@plannotator/opencode@latest"] }`.
- Honor `--skip-opencode` / `PLANNOTATOR_SKIP_OPENCODE_INSTALL` / `skipInstall.opencode` exactly as the command stubs do; mirror in `install.ps1` and `install.cmd`.

Consent model: the same as every other config write the installer performs (no separate prompt; the opt-out flags and the honest "written / left untouched / skipped" report are the consent flow). Release-note-worthy: a fresh install now works on OpenCode without editing config.

### 7.2 Timeout: skill guidance versus CLI self-detach

Two options were weighed.

Self-detach (the CLI `setsid`s or re-parents the server so a shell-tool group kill cannot reach it): the server survives, but the decision has no way back to the agent, because the shell tool's stdout is the delivery channel and it is gone. The session becomes an orphan the user must clean up, and Windows has no `setsid` (Bun's `detached` creates a new process group there, but the shell tool's kill semantics differ and were not verified). Rejected as the primary fix.

Skill guidance plus graceful SIGTERM (recommended): the three lightweight skills state, in the same words as `plannotator/SKILL.md:30`, that the command blocks until the human decides and must be run with a long or unlimited timeout (OpenCode's shell tool accepts a `timeout` parameter, `shell.ts:618`; Claude Code's Bash accepts one too). On SIGTERM the CLI pushes the `session-ended` event from 4.3 before exiting, so the tab immediately offers Copy and Download, and the draft plus submission record remain on disk. Data is not lost; only the live hand-off is, and the user is told so at the moment it happens.

Also: the stubs and the skills must say the same thing, since the stub shadows the skill when the plugin is not loaded (`command/index.ts:134-135`). Simplest: stop installing the stubs and let the skill be the command. This needs one verification during implementation: that `command.execute.before` (`apps/opencode-plugin/index.ts:448`) fires for a skill-sourced command of the same name. If it does not, keep the stubs but generate their body from the skill text so there is one source.

### 7.3 Exports, V2, and #1196

`exports["."]` cannot simply be repointed: the maintainer's comment in `package.json` documents why OpenCode 1 must find `main` and OpenCode 2 must find `exports["."]`. The fix is that the V2 adapter (`server.ts`) gains command interception equivalent to `index.ts:448-517` before anything else moves, so both entrypoints intercept. Whether the V2 API exposes a command hook was not verified from this checkout and is the first question for that work. #1196 (an issue, not a PR) must list "annotate, review, and last interception on V2" as a precondition; until then OpenCode 2 users are on the skill path of 7.2, which is why 7.2 must land first.

### 7.4 cli-bridge detach

`cli-bridge.ts:346-347` should detach on non-Windows unconditionally (the abort signal decides whether we will ever kill the group, not whether the child should have its own group). `handleCliCommand` should also accept and forward an abort signal so an abandoned slash command can be cleaned up the way `submit_plan` is (`index.ts:542`, `:555`). Align the 1s SIGKILL escalation (`:368-374`) with OpenCode's 3s so a server mid-write is not force-killed sooner by our own bridge than by the host.

---

## 8. Phasing

Each phase ships alone.

Phase 1, fix now (about a week, mostly client, no new endpoints):
- `submitDecision` with visible failure, `res.ok` on plan approve/deny, real error on review, recovery sheet with Copy and Download, outbox in `localStorage`, pending-outbox cookie flag. (B4)
- Settings capability seam: `surface` + `capabilities`, `mode` kept as a deprecated alias; document tab set from 3.1; Default Save Action available on document surfaces; Notes tab keyed on "has a document"; copy at `ExportModal.tsx:439/479/524` becomes a jump into Settings; `ui-settings.md` rewritten. (A)
- `cli-bridge.ts:346-347` unconditional detach; abort signal threaded through `handleCliCommand`. (B7)
- Timeout guidance in the three lightweight skills; stub body decision per 7.2. (B1, B2)

Phase 2, follow-up (about a week, both runtimes):
- Path-keyed draft identity in `packages/core`, one-release fallback migration, `pruneDrafts` at start, unplaced-annotation handling on restore. (B5)
- Submission record widened to every stable-identity document session plus plan and review; `session-ended` SSE on SIGTERM; client listener. (B6, B1)
- Installer writes `opencode.json` on all three install scripts. (B2)

Phase 3, feature (a few days after phase 1):
- `annotations` in the notes payload on both runtimes; `on submit` auto-save trigger; the Saving tab's trigger choice. (C, items 1 and 2)

Deferred, own design: feedback written into the source document (C, item 3); V2 command interception and #1196 (7.3), which starts with the API verification.

Release-note-worthy: visible submit failures with Copy/Download recovery on every surface; identical Settings on plan and annotate; OpenCode install no longer needs a manual config edit; drafts survive agent edits to the file; the pending-outbox notice; timeout guidance in the skills.

### Needs the reporter first

- Which launch path they use on OpenCode: is `@plannotator/opencode` in their `opencode.json`? If yes, "immediately closes" is not the shell timeout and the investigation has no explanation for it; if no, it is B2 plus B1.
- The exact OpenCode version.
- "Codex keeps it open longer": Codex has its own tool timeout and was not investigated; the same SIGTERM story likely applies but is unverified.
- For C item 3: what "inside the actual plan itself" should look like.

---

## 9. Recommendation

Ship phase 1 as one release: it removes every silent data-loss path the reporter hit, makes the two settings screens the same screen, and is entirely client-side plus one-line bridge and skill changes, so it carries no two-runtime cost. Phase 2 is where the durable layer catches up on the server side and must be done on Bun and Pi together. Phase 3 is the reporter's feature and is small once phase 1 has unified Saving.

Top three design decisions:

1. Capabilities, not modes, in `packages/ui`. `Settings` and the export modal branch on what a session can do (`decisionFlow`, `readOnly`, has-document) with `mode` retained only as a deprecated alias for hosts. This is the ruling made concrete, and it is why archive and share surfaces get the full tab set instead of leaking plan-only extras by accident (`Settings.tsx:856`).
2. The recovery sheet is the resilience mechanism; browser storage is a bonus. Because local sessions use random ports, `localStorage` cannot promise cross-session recovery, so the design puts the composed feedback in the user's hands (Copy, Download) at the moment of failure and relies on server-side drafts with a path-stable key for the reopen story. Anything that claimed more would be untrue on the most common configuration.
3. Graceful SIGTERM over self-detach on the OpenCode skill path. Keeping the server alive after the shell tool kills its group would strand the decision with no channel back to the agent and would not exist on Windows; telling the user immediately, and keeping the draft and submission record on disk, is the outcome that is actually achievable on every platform.

---

## 10. Out of scope

- Any change to the plan hook's allow/deny contract or to agent switch.
- Review's own tab set (Git, Analysis, Comments, AI).
- Rebuilding any document UI outside `@plannotator/ui` (see `packages/ui/README.md`).
- Live-app session persistence beyond the outbox and sheet.
- OpenCode 2 loader verification (not in the reference checkout).
