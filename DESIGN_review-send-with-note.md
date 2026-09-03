# Send with additional feedback — code review

Status: spec, not implemented. Sibling of the annotate control approved on PR #1436.

---

## 1. Problem + prior art

A reviewer who wants to say one whole-review thing — "fine, but rebase first", "ship it after you split the migration" — has no place to type it in the code review app. The only composers are anchored: a line/token selection (`AnnotationToolbar.tsx:212-228`), a file comment, a PR-description note, or a PR-comment note. Review-level (`scope: 'general'`) `CodeAnnotation`s already exist and already export, but the only producer is the Call Flow surface (`packages/review-editor/utils/callFlowAnnotations.ts:77-83`) — nothing lets a human author one. So the review-wide remark either gets glued onto an unrelated line comment or gets typed into the terminal after the session closes. PR #1436 solved the same problem for annotate with a joined split button `[Send Feedback | ⌄]` whose caret opens a right-anchored `w-[22rem]` panel holding one auto-growing textarea (`rows=2`, 144px then scrolls) and a footer of `submitHint` + a **distinct** action button labeled "Send with additional feedback"; Enter is a newline, `Mod+Enter` is that action, Esc closes and keeps the half-typed text, outside click closes, and the note is materialized at submit time as a `GLOBAL_COMMENT` so it rides the existing export and the `/api/feedback` annotations array with zero server change (`packages/editor/components/AnnotateSendControl.tsx`, `commitSubmitNote` in `packages/editor/App.tsx`). This spec brings that exact contract to `packages/review-editor`, with `scope: 'general'` playing the role `GLOBAL_COMMENT` plays in annotate.

---

## 2. Current review submit anatomy

### 2.1 The desktop toolbar

`packages/review-editor/components/AgentReviewActions.tsx:36-79` renders agent-mode actions:

| button | source | visibility |
|---|---|---|
| Close | `AgentReviewActions.tsx:39-44` (`ExitButton`) | always |
| Send Feedback | `AgentReviewActions.tsx:46-56` (`FeedbackButton`) | **only when `totalAnnotationCount > 0`** |
| Approve | `AgentReviewActions.tsx:59-75` (`ApproveButton`, `dimmed` when annotations exist, with a hover tooltip "Your N annotations won't be sent if you approve.") | always |

Mounted at `packages/review-editor/App.tsx:4283-4292`, inside `{!isCompactTouchLayout && (origin ? (` at `App.tsx:4093` — i.e. **desktop only, agent mode only**. The platform (PR) branch is `App.tsx:4294-4348`: Close / Post Comments / Approve, both routed through `openPlatformDialog(...)`.

All three review buttons pass `labelBreakpoint="lg"`, so `FeedbackButton` renders `shortLabel` at `lg` and the full label only at `xl` (`packages/ui/components/ToolbarButtons.tsx:41-50`); below `lg` the button is icon-only. Any replacement must reproduce that or it widens the toolbar at `md`.

### 2.2 The three submit handlers

- `handleSendFeedback` — `App.tsx:3489-3521`. Guards `totalAnnotationCount === 0` → `setShowNoAnnotationsDialog(true)` (`:3490-3493`). Otherwise POSTs `{ draftGeneration, approved: false, feedback: feedbackMarkdown, annotations: allAnnotations, agentSwitch? }` to `/api/feedback` (`:3499-3510`) and sets `submitted = 'feedback'`.
- `handleApprove` — `App.tsx:3540-3565`. POSTs `{ draftGeneration, approved: true, feedback: 'LGTM - no changes requested.', annotations: [] }`. The inline comment at `:3549` says the feedback string is *"unused — integrations branch on `approved` flag"*. It is right (§4.2).
- `handleExit` — `App.tsx:3524-3537`. `POST /api/exit`.

Supporting state: `annotations` / `annotationsRef` at `App.tsx:337-339`; `allAnnotations` (local + SSE external, deduped) at `App.tsx:888-904` with `allAnnotationsRef` at `:905-906`; `feedbackMarkdown` at `App.tsx:3445-3465`; `totalAnnotationCount = allAnnotations.length + editor + description + comment` at `App.tsx:3466`; `identity = useConfigValue('displayName')` at `App.tsx:734`; `addCodeAnnotationsWithHistory` (the undo-recording adder) at `App.tsx:1942-1953`; draft autosave over `allAnnotations` at `App.tsx:909-917`.

### 2.3 Keyboard

The global `Mod+Enter` listener is `App.tsx:3785-3838`. Two lines matter:

- `App.tsx:3805-3806` — `const tag = (e.target as HTMLElement)?.tagName; if (tag === 'INPUT' || tag === 'TEXTAREA') return;` The global handler **already yields to any focused textarea**, so a note field owning `Mod+Enter` locally needs no changes here and cannot double-fire.
- `App.tsx:3820-3826` — agent mode: zero annotations → `handleApprove()`, otherwise → `handleSendFeedback()`.

### 2.4 Where a review-level note already renders and exports

- **Sidebar**: `ReviewSidebar.tsx:196-237` splits `scope === 'general'` out of the file grouping into `generalAnnotations` (sorted newest-first at `:204`); rendered under a sticky "General" header at `ReviewSidebar.tsx:470-481`; the card gets a `general` badge at `ReviewSidebar.tsx:262-266`.
- **Agent export**: `renderGeneralComments` at `packages/review-editor/utils/exportFeedback.ts:251-267` emits a `## General` section; the split is at `:324-326`, and the section is appended after the file groups at `:349` and `:382`.
- **Navigation**: `handleNavigateToAnnotation` (`App.tsx:3176-...`) selects but does not scroll for an annotation with nothing in the diff to point at; general-scope cards therefore behave as they already do for Call Flow findings.
- **Platform submission**: `buildFileScopedBody` at `ReviewSubmissionDialog.tsx:112-124` explicitly folds `scope === 'general'` comments into the posted PR review body.

So the entire receiving half of this feature is already built. What is missing is a producer.

---

## 3. Design

### 3.1 `ReviewSendControl` — the split button

One joined pill, both segments the shared `Button` (`variant="outline"`, `size="xs"`), hairline divider, identical to the approved annotate control:

```
[ ✈ Send Feedback │ ⌄ ]
```

- **Left segment** — the incumbent send, and it never changes meaning. `iconLeft={<Send className="size-3.5" />}`, `className="rounded-r-none border-r-0"`, and the same responsive label spans `FeedbackButton` uses at `labelBreakpoint="lg"` (`hidden lg:inline xl:hidden` for `Send`, `hidden xl:inline` for `Send Feedback`) so the toolbar width is unchanged below `xl`. Loading label `Sending...`.
- **Right segment** — caret only, `className="rounded-l-none px-1.5"`, `aria-expanded`, `data-review-note-toggle="true"`, chevron rotates 180° when open. Roughly +22px on the toolbar; nothing else moves.
- **Disabled** — both segments take `disabled={busy}` where `busy = isSendingFeedback || isApproving || isExiting` (the same expression `AgentReviewActions.tsx:34` already computes). An open panel closes on `busy` becoming true.

**Panel** (`data-review-note-composer="anchored"`): `absolute right-0 top-full z-50 mt-1.5 w-[22rem] max-w-[calc(100vw-2rem)] rounded-lg border border-border bg-popover p-1.5 shadow-xl`, containing only:

1. the textarea — `rows={2}`, auto-grows to `NOTE_MAX_HEIGHT_PX = 144` then scrolls, `resize-none`, `focus-visible:ring-1 focus-visible:ring-ring/40`, `data-review-note-input="true"`, placeholder `Add a note...`, autofocused on open;
2. a footer row: `submitHint` (from `@plannotator/ui/utils/platform`) on the left, and on the right a **distinct** `Button variant="outline" size="xs"` with the `Send` icon labeled **"Send with additional feedback"** (`data-review-note-send="true"`), disabled while the trimmed text is empty.

Keys, exactly as approved: `Enter` = newline (falls through); `Mod+Enter` = the distinct action; `Escape` = close, `preventDefault` + `stopPropagation`, **keep the typed text**; pointerdown outside the container closes. The text lives in the control (a keystroke must not re-render the review header).

Placement note: the panel is right-anchored under the split, which sits immediately left of Approve. Approve's own "annotations won't be sent" tooltip (`AgentReviewActions.tsx:66-73`) is also `z-50` and anchored `right-0` on its own wrapper; the panel is wider and will cover it while open. That is correct — the panel is a deliberate modal-ish surface and the tooltip is hover-only.

### 3.2 Zero-annotation state

Adopt the annotate contract verbatim: **the split renders in both states**, and with `totalAnnotationCount === 0` the primary click opens the panel instead of calling `handleSendFeedback` (which would only raise the "No Annotations" dialog, `App.tsx:3490-3493`). Title becomes `Send Feedback: write a quick note`.

This is purely additive — at zero annotations the header goes from `[Close][Approve]` to `[Close][Send Feedback ⌄][Approve]`. **No existing button is removed or hidden**: `ExitButton` and `ApproveButton` are untouched, and the `FeedbackButton` that used to appear at `count > 0` is replaced in place by a control whose left segment is the same button with the same label, icon, breakpoints and handler. Approve keeps `variant="success"` and stays the visually dominant zero-state action.

The global `Mod+Enter` route is **not** changed: at zero annotations it still goes to Approve (`App.tsx:3820-3826`). The split's primary is a pointer affordance; the note's chord is `Mod+Enter` *inside the field*, which the global listener already declines (`App.tsx:3805`).

### 3.3 Platform (PR) mode: out of scope

The caret is added to `AgentReviewActions` only. Platform mode already has a general-comment textarea in its submission dialog (`ReviewSubmissionDialog.tsx:365-375`) whose contents ride the posted review body, so a second composer for the same field would be two truths. `buildFileScopedBody` (`ReviewSubmissionDialog.tsx:112-124`) would happily carry a general-scope note into a platform post, which is exactly why the affordance must not exist twice.

### 3.4 Materializing the note (App)

Mirror `commitSubmitNote` (`packages/editor/App.tsx`), typed as `CodeAnnotation` with the general shape the Call Flow producer already uses (`callFlowAnnotations.ts:77-83`):

```ts
const commitReviewNote = useCallback((text: string): string | null => {
  const trimmed = text.trim();
  if (!trimmed) return null;
  const note: CodeAnnotation = {
    id: `review-note-${Date.now()}`,
    type: 'comment',
    scope: 'general',
    filePath: '', lineStart: 0, lineEnd: 0, side: 'new',
    text: trimmed,
    createdAt: Date.now(),
    author: identity,
  };
  annotationsRef.current = [...annotationsRef.current, note];
  setAnnotations(annotationsRef.current);
  return note.id;
}, [identity]);
```

Three deliberate omissions, each load-bearing:

- **Not** `addCodeAnnotationsWithHistory` (`App.tsx:1942-1953`) — the note exists for the duration of one submit; an undo of it after the send would restore nothing the agent has not already been told. Same reasoning as annotate.
- **Not** `withPRContext(...)` — a review-wide note belongs to the session, not to one PR layer. `annotationMatchesPrScope` (`packages/review-editor/utils/annotationScope.ts:10-19`) passes any annotation carrying neither `prUrl` nor `diffScope` under every scope, so an unstamped note survives an in-place PR switch and a layer/full-stack toggle. Stamping it would make it disappear from the sidebar when the reviewer switches PRs mid-session.
- **Not** a `filePath` — `''`/`0`/`0` are the documented sentinels (`packages/ui/types.ts:155-158`); giving the note a real path would file it under a diff group and export it as a comment on a line nobody selected.

Submit waits one render, exactly as annotate does, because `feedbackMarkdown` (`App.tsx:3445-3465`) and `handleSendFeedback` close over `allAnnotations`:

```ts
const [pendingNoteId, setPendingNoteId] = useState<string | null>(null);

const handleSubmitReviewNote = useCallback((text: string) => {
  if (busy || submitted) return;
  const id = commitReviewNote(text);
  if (!id) { if (totalAnnotationCount > 0) handleSendFeedback(); return; }
  setPendingNoteId(id);
}, [...]);

useEffect(() => {
  if (!pendingNoteId) return;
  if (!allAnnotations.some(a => a.id === pendingNoteId)) return;
  setPendingNoteId(null);
  handleSendFeedback();
}, [allAnnotations, handleSendFeedback, pendingNoteId]);
```

Committing into state rather than threading the note through the POST body is what makes the sidebar, the `## General` export section, the platform body builder and the draft all pick it up for free. Consequence worth stating: for the one render between commit and submit the note is in `allAnnotations`, so `useCodeAnnotationDraft` (`App.tsx:909-917`) may autosave it — harmless, because the server deletes the draft on a durable submit (`packages/server/review.ts:3406`), and if the POST fails the draft is the recovery copy, which is the behavior the reviewer wants.

The control is wired only when `origin` is set (a real session, not demo) and `!submitted`, matching how `AgentReviewActions` is already gated at `App.tsx:4093`.

---

## 4. Payload + archive trace

### 4.1 Send-with-note: zero server change, confirmed on both runtimes

**Bun — `packages/server/review.ts:3381-3419`.** The body is a bare `as` cast, no schema, no field whitelist:

```ts
const body = (await req.json()) as {
  approved?: boolean;
  feedback: string;
  annotations: unknown[];      // review.ts:3386
  agentSwitch?: string;
  draftGeneration?: number;
};
```

`annotations` is `unknown[]` and is never indexed into. It is read for `.length` only (`:3400`), then forwarded verbatim to `archiveReviewSubmission` (`:3401-3405`) and to `resolveDecision` (`:3407-3412`). `CodeAnnotation` is not imported in this file. Adding one more object to the array is invisible to it.

**Pi — `apps/pi-extension/server/serverReview.ts:3359-3388`.** Line-for-line equivalent: `parseBody` (`:3361`), `const annotationList = (body.annotations as unknown[]) || []` (`:3368`), same `hasContent` (`:3369-3371`), same archive call (`:3372-3376`), same `resolveDecision` (`:3378-3383`). Divergences are cosmetic (helper style; a malformed body degrades to `{}` in Pi and 500s in Bun; Pi imports the archive from the vendored `apps/pi-extension/generated/feedback-archive.ts` at `serverReview.ts:10`). No change needed in either.

**Consumers.** `waitForDecision()` resolves `{ approved, feedback, annotations: unknown[], agentSwitch?, exit? }` (`review.ts:1730-1745`). On the non-approved path every consumer prints/sends `result.feedback` and appends the denied suffix when `result.annotations.length > 0` — `apps/hook/server/index.ts:1090-1097`, `apps/opencode-plugin/commands.ts:195-199`, `apps/opencode-plugin/cli-bridge.ts:577-596`, `apps/pi-extension/index.ts:678-699`, `apps/review/server/index.ts:88-95`. The note reaches the agent inside `feedbackMarkdown`'s `## General` section, and its presence in the array keeps the suffix behavior correct.

**Verdict: zero server change.** No blocker.

### 4.2 Archive (#1438)

`archiveReviewSubmission` wrappers: `review.ts:908-929` and `serverReview.ts:891-910`, both `surface: "review"`, both gated on `resolveFeedbackHistory(loadConfig())`. Decision label at `review.ts:3404` / `serverReview.ts:3375`:

```ts
approved ? (hasContent ? "approved-with-notes" : "lgtm") : "feedback"
```

A send-with-note is `approved: false` → `decision: "feedback"`, unchanged. `packages/shared/feedback-archive.ts:364-366` stores the `feedback` string as-is and maps the array through `normalizeAnnotation`; `counts.annotations` picks the note up automatically and the markdown sidecar body is `record.feedback` (`:342`), which already contains the `## General` section. **Nothing extra is needed for the note to land in the archive.**

One honest caveat: `normalizeAnnotation` (`feedback-archive.ts:263-297`) copies a fixed allowlist — `id, type, text, originalText|selectedText|tokenText, filePath|file, lineStart, lineEnd, side, blockId, diffContext, severity, inReplyTo, source, author, images.length` — and `scope` is **not** in it. The note is archived (as `{ id, type: "comment", text, author }` with no `filePath`), but the record does not say it was review-level. Adding `scope?: string` to `FeedbackAnnotationRecord` (`:150-168`) plus two lines in `normalizeAnnotation` is an additive v1 field explicitly sanctioned by the "fields are added, never repurposed" contract at `feedback-archive.ts:29-33`; it also needs the Pi vendored copy regenerated. Not required by this feature — see open question 3.

**Pre-existing bug found while tracing.** `hasContent` is true for *every* review approval today, because `handleApprove` always sends the non-empty placeholder `'LGTM - no changes requested.'` (`App.tsx:3549`). So a bare LGTM from the review UI archives as `approved-with-notes` with the placeholder as its body and a sidecar file, and the `"lgtm"` decision label is unreachable in production. The test that covers it posts `feedback: ""`, which no client does (`packages/server/feedback-archive.test.ts:177-193`). Out of scope to fix here, but it is the thing to fix first in the LGTM phase below.

---

## 5. LGTM with a note — recommendation: **not in v1**

### What LGTM sends today

`handleApprove` (`App.tsx:3540-3565`) POSTs `approved: true`, the placeholder feedback string, and `annotations: []`. The server does *not* drop either field on the approved path — it archives both and resolves both (`review.ts:3396-3412`, `serverReview.ts:3367-3383`). The archive even has a purpose-built `approved-with-notes` decision and sidecar for exactly this case.

### The blocker

Every agent-facing consumer discards `result.feedback` when `result.approved` is true and sends a canned prompt instead:

| consumer | line | behavior |
|---|---|---|
| Claude Code CLI | `apps/hook/server/index.ts:1090-1091` | `console.log(getReviewApprovedPrompt(detectedOrigin))` |
| OpenCode native | `apps/opencode-plugin/commands.ts:195-196` | `getReviewApprovedPrompt("opencode")` |
| OpenCode CLI bridge | `apps/opencode-plugin/cli-bridge.ts:577-581` | `getReviewApprovedPrompt("opencode")` |
| Pi | `apps/pi-extension/index.ts:668-677` | `getReviewApprovedPrompt("pi", loadConfig())`, then `return` |
| plain review CLI | `apps/review/server/index.ts:88-95` | already emits `feedback` — the only one that would work today |

So "Approve with a note" built on the same zero-server-change payload would archive the note and show it in the UI while **four of five runtimes silently never deliver it to the agent**. Shipping a composer whose text vanishes on four hosts is worse than not shipping it: the reviewer gets a confirmation and the agent gets a bare LGTM.

### Recommendation

**Ship v1 as the Send-Feedback split only.** Treat LGTM-with-note as a tightly scoped phase 2 that changes the four consumer call sites — not the servers, which already carry everything. Phase 2 is small but *coupled*, which is the real reason it must not be smuggled into v1: a consumer that starts printing `result.feedback` on approve would, on the current client, append the literal string `LGTM - no changes requested.` to every single approval. So phase 2 is necessarily three changes landing together:

1. `handleApprove` stops sending the placeholder (`feedback: noteText` or `''`), which is also what finally makes the dormant `"lgtm"` archive decision reachable and the bare-approval sidecar stop being written;
2. the four consumers print/send the approved prompt and then the note when `result.feedback.trim()` is non-empty;
3. an Approve split reusing the *same* `ReviewSendControl` field component, with its distinct action labeled "Approve with a note", plus a rewording of the `showApproveWarning` dialog (`App.tsx:4979-4993`) whose subMessage currently says "To send your feedback, use Send Feedback instead."

Rationale for the split rather than one shared panel with two actions: the two decisions have opposite consequences (Approve discards the reviewer's annotations; Send carries them), the toolbar already keeps them visually distinct (`outline` vs `success`), and one panel offering both would make "which button did I just press" a hover-tooltip question at the moment it matters most. When phase 2 lands, it should be a second caret on `ApproveButton` sharing the field component, not a shared panel.

---

## 6. Compact / touch surface

There is **no** `CompactPlanReview` analogue in review. The compact submit path is: header hamburger → `ActionMenu` popup → destination toggle + 1–3 rows.

- `isCompactTouchLayout` = `useCompactTouchLayout()` (`packages/ui/hooks/useIsMobile.ts:36-54`; `(max-width: 1024px) and (pointer: coarse)`), called at `App.tsx:332`.
- `compactReviewActions: CompactReviewAction[]` built at `App.tsx:3905-3944`; `compactActionBusy` at `App.tsx:3904`.
- `CompactReviewAction` is a **closed union**: `id: 'exit' | 'feedback' | 'approve' | 'copy'` (`ReviewHeaderMenu.tsx:27-33`).
- Rendered as plain `ActionMenuItem` rows at `ReviewHeaderMenu.tsx:159-171`, inside the compact block `:124-174`; the only non-row container is `<div className="px-3 py-2 space-y-2">` at `:126-158` (section label + destination grid). Panel is a scrollable popup, `w-[min(18rem,calc(100vw-1rem))]` (`:87-90`).
- The whole desktop toolbar including `AgentReviewActions` is behind `!isCompactTouchLayout` (`App.tsx:4093`), so the split control is simply absent in compact.

### Spec

Do **not** put a textarea in the `ActionMenu` popup: it is a scrollable dropdown that closes on outside pointerdown and on row click, and raising the soft keyboard inside it fights the panel's `max-h` viewport math. Instead:

1. Add `'note'` to the `CompactReviewAction` id union (`ReviewHeaderMenu.tsx:28`) and a case to `CompactReviewActionIcon` (`ReviewHeaderMenu.tsx:391-408`). Purely additive: no existing row is removed, reordered, or hidden.
2. In `App.tsx:3905-3944`, insert a `note` row **after** `exit` and before the conditional `feedback` row, present in the with-origin agent-mode branch only (`!platformMode`), label `Add a note`, subtitle `Sent with your annotations` when `totalAnnotationCount > 0`, `disabled: compactActionBusy`, `onSelect: () => setCompactNoteOpen(true)`.
3. Export `ReviewNoteDialog` from `ReviewSendControl.tsx` and render it from `App.tsx` beside the other dialogs (near `App.tsx:4979`). It is a `Dialog`/`DialogContent` (the same primitive `ReviewSubmissionDialog` uses) holding the identical field component plus the same "Send with additional feedback" action, following the proven compact conventions from that dialog and the annotation toolbar: `data-pn-mobile-editable` on the textarea (`packages/ui/theme.css:879-880`), `initialFocus={false}` under compact so opening the sheet does not raise the keyboard (`ReviewSubmissionDialog.tsx:350`, `AnnotationToolbar.tsx:219`), submit button carrying `data-pn-touch-target`.

`onSubmit` is the same `handleSubmitReviewNote`, so compact and desktop share one commit path and one payload.

---

## 7. Shortcuts

New scope file `packages/ui/shortcuts/code-review/reviewNote.shortcuts.ts`, mirroring `plan-review/annotateNote.shortcuts.ts` from #1436 but with the **approved** chords (that PR's scope file still documents `Enter` from the pre-review one-line design and is stale against its own component — worth fixing there):

```ts
export const reviewNoteShortcuts = defineShortcutScope({
  id: 'review-note',
  title: 'Quick Note',
  shortcuts: {
    submit: {
      description: 'Send the note with your annotations',
      bindings: ['Mod+Enter'],
      section: 'Actions',
      hint: 'Available while the Send control’s note field is open. Enter inserts a newline.',
      displayOrder: 12,
    },
    cancel: {
      description: 'Close the note field without sending',
      bindings: ['Escape'],
      section: 'Actions',
      hint: 'The typed note is kept for the rest of the session but is not sent.',
      displayOrder: 14,
    },
  },
});
```

Wiring: one export line in `packages/ui/shortcuts/index.ts` after `:35`; one entry in `reviewSettingsShortcutRegistry` in `packages/review-editor/shortcuts.ts` (after `reviewEditorShortcuts`). Scope id `review-note` follows the `review-*` convention of the other seven code-review scopes and is unique. As with annotate, the handlers stay local to the input — the scope exists so the chords appear in the in-app help modal and in the auto-generated `/docs/reference/keyboard-shortcuts` page. The existing `reviewEditorShortcuts.submit` (`Mod+Enter`, "Approve / Send feedback", `shortcuts.ts:20-25`) is left alone; the two never collide because the global listener declines textarea targets (`App.tsx:3805`).

---

## 8. Component placement decision

**Decision: `packages/review-editor/components/ReviewSendControl.tsx`. Duplicate the field/panel; do not extract to `packages/ui` now.**

Rationale:

1. **The props genuinely differ.** The annotate control takes `hasFeedback` and flips the primary between plain-send and open-panel; review's version must additionally carry `labelBreakpoint`-style responsive label spans, a `shortLabel`, the three-way `busy` expression, and a compact `ReviewNoteDialog` sibling that annotate does not have (annotate's compact form is an always-expanded sheet inside a sectioned review stage; review has no such stage). A single shared component would need a `variant` union covering both, which is more surface than two ~180-line files.
2. **#1436 is approved and unmerged.** Extracting to `packages/ui` means editing `packages/editor/components/AnnotateSendControl.tsx` on that branch — a conflict plus re-review of already-approved work, for no user-visible gain.
3. **`packages/ui` is published.** `packages/ui/README.md` makes it a host-extension surface with `configurePlannotatorUI()` seams; a control that both first-party apps must keep in lockstep raises the cost of any later divergence in one of them, and this control is not part of the reusable document UI a host embeds.

A `packages/ui` home would be additive and therefore *allowed* — the rule is only that `packages/ui` changes be additive seams, which a new file is. It is simply not yet worth it. **Tripwire:** if a third surface ever needs the field (a plan-review note, a guide note, a host), extract `SubmitNoteField` — the textarea + auto-grow + key handling, roughly 60 lines and the only genuinely identical part — into `packages/ui/components/SubmitNoteField.tsx` and have both controls compose it. Do that as its own PR after #1436 lands, never mixed into a feature.

**Toolbar integrity.** Nothing is removed or hidden anywhere in this spec: `ExitButton`, `ApproveButton`, `FeedbackButton`'s label/icon/handler, the platform-mode branch, the `showNoAnnotationsDialog` / `showApproveWarning` / `showExitWarning` dialogs, `Copy Feedback`, and all four existing compact rows survive verbatim. The only structural edit inside `AgentReviewActions.tsx` is swapping the `{hasAnnotations && <FeedbackButton .../>}` block (`:46-56`) for `<ReviewSendControl .../>` whose left segment *is* that button, guarded so a host that does not pass a `note` prop falls back to the incumbent `FeedbackButton` unchanged — the same escape hatch `AppHeader.tsx` uses in #1436.

---

## 9. Test plan

Repo rules apply: every test names the regression it guards, nothing snapshots incidental prose, no `process.env` / real `~/.plannotator` mutation at module scope, all server work under a temp `PLANNOTATOR_DATA_DIR`. There is currently **no test in `packages/review-editor` that mounts `App`** (the review App pulls in dockview, the Pierre worker pool and the Shiki bundle), so — unlike #1436, which mounted the annotate App — the coverage here is component-level plus pure plus server-level. That is a deliberate departure, not an omission.

**A. `packages/review-editor/components/ReviewSendControl.test.tsx`** — `describe.if(hasDom)`, precedent `packages/ui/components/AnnotationToolbar.commentOnly.test.tsx`.

1. *The left segment never sends the note.* Type into the panel, then click the primary; assert `onSend` fired and `onSubmit` did not. Guards the single most likely "helpful" regression: someone merges the two actions into one button, at which point a reviewer who typed a note and clicked Send loses it silently.
2. *`Enter` is a newline, `Mod+Enter` submits.* Dispatch `Enter` → `onSubmit` not called; dispatch `Enter` with `metaKey` → called once with the trimmed text; repeat with `ctrlKey`. Guards a revert to the pre-review one-line field, which would truncate any multi-line note at the first newline.
3. *`Escape` closes and keeps the text.* Assert the panel unmounts, `onSubmit` was not called, and reopening shows the same value. Guards clearing-on-close, which throws away a half-typed note; and the `stopPropagation` that keeps Escape from also reaching the review app's own Escape ladder (`App.tsx:1739-1782`).
4. *The distinct action is disabled for empty and whitespace-only text.* Guards submitting an empty `scope: 'general'` annotation, which would export as a blank bullet under `## General`.
5. *Zero-annotation primary opens the panel instead of sending.* `hasFeedback={false}` → click primary → panel open, `onSend` not called. Guards a regression that raises the "No Annotations" dialog from a button whose whole purpose is the note.
6. *Label freeze* — one assertion that the panel's action button reads exactly `Send with additional feedback`, with a comment marking it as a deliberately frozen maintainer-approved string (per the annotate contract), not a snapshot.

**B. `packages/review-editor/utils/exportFeedback.reviewNote.test.ts`** — pure, no DOM. Precedent: `exportFeedback.workspace.test.ts`.

7. A `scope: 'general'` note renders under `## General` and creates **no** file group. Assert the output contains the note text after a `## General` heading and does **not** contain a heading for the empty path. Guards giving the note a `filePath` or `scope: 'line'`, which would export it as a comment on a file that is not in the diff.
8. The note co-exists with placed annotations: with one line comment and one note, the export contains both the file group and the General section. Guards the `general`/`placed` partition at `exportFeedback.ts:324-326` being bypassed.

**C. `packages/server/review-note-payload.test.ts`** — both runtimes in one file, precedent `packages/server/api-404-guard.test.ts` (imports `startReviewServer` from `./review` **and** from `../../apps/pi-extension/server`), sandboxed with the `useTempDataDir` helper from `packages/server/feedback-archive.test.ts`.

9. For each runtime: `POST /api/feedback` with `approved: false`, a `feedback` string containing a `## General` section, and an `annotations` array whose last element is `{ id, type: 'comment', scope: 'general', filePath: '', lineStart: 0, lineEnd: 0, side: 'new', text }`. Assert `waitForDecision()` resolves with that element **present and unmodified** in `result.annotations`, and that `result.feedback` is byte-identical to what was posted. Guards the one thing that would break zero-server-change: a future body validator, whitelist or `CodeAnnotation` schema landing on either handler and dropping an entry it does not recognise.
10. Same request → the archive index records `decision: "feedback"` with `counts.annotations` including the note, and a sidecar is written. Guards a regression in the archive's `hasContent` computation (`review.ts:3399-3400`) that would demote a note-carrying submission to a decision-only line.

**D. `packages/review-editor/components/ReviewHeaderMenu.mobile.test.tsx`** (extend the existing file).

11. Given a `compactActions` array containing `note` plus the incumbent `exit`/`feedback`/`approve`, all four rows render, in that order, and none is disabled by the presence of the new one. Guards the standing toolbar-integrity rule at the surface where the closed-union edit actually risks it.

Not tested, on purpose: the `useEffect`-deferred submit (it is App wiring with no review-App test harness — covered indirectly by C9's payload shape and by manual QA), and the shortcut registry's uniqueness (already enforced by `packages/ui/shortcuts.test.ts`).

Manual QA line for the release checklist: desktop agent-mode review with and without annotations; note + existing line comment sent together and confirmed in the agent's message under `## General`; compact-touch note dialog on a real phone; Escape from the panel does not also collapse the file tree or close the sidebar.

---

## 10. Open questions for the maintainer

1. **Phase 2 timing.** Is the coupled LGTM-with-note change (client stops sending the `'LGTM - no changes requested.'` placeholder + four consumer call sites start delivering an approval note) something you want queued right behind this, or parked? It is the change that also makes the dormant `"lgtm"` archive decision reachable for the first time and stops a bare approval writing a sidecar — a small archive-shape change in its own right.
2. **`scope` in the archive.** Should `normalizeAnnotation` (`packages/shared/feedback-archive.ts:263-297`) gain `scope?: string` so a review-level note is distinguishable from a line comment in `index.jsonl`? Additive and sanctioned by the field contract at `:29-33`, but it also means regenerating the Pi vendored copy — say the word and it rides along, otherwise the note archives without its scope.
3. **Zero-annotation header.** Confirm you want the split rendered at `totalAnnotationCount === 0` (mirroring annotate), which adds a `Send Feedback ⌄` button to the zero-state review header next to Approve. The alternative — render the split only at `count > 0`, exactly where `FeedbackButton` appears today — leaves the zero-state header byte-identical but makes the note unreachable in precisely the case ("nothing to annotate, one remark to make") it is most useful for.

---

## 11. Estimated diff footprint

| file | change |
|---|---|
| `packages/review-editor/components/ReviewSendControl.tsx` | **new**, ~200 lines (split control + field + `ReviewNoteDialog`) |
| `packages/review-editor/components/AgentReviewActions.tsx` | ~+22 / −11 (swap the `FeedbackButton` block, keep it as the no-`note` fallback) |
| `packages/review-editor/App.tsx` | ~+62 (`commitReviewNote`, `handleSubmitReviewNote`, pending-id effect, `noteControl` memo, compact row, dialog mount) |
| `packages/review-editor/components/ReviewHeaderMenu.tsx` | ~+8 (union id + icon case) |
| `packages/ui/shortcuts/code-review/reviewNote.shortcuts.ts` | **new**, ~28 lines |
| `packages/ui/shortcuts/index.ts` | +1 |
| `packages/review-editor/shortcuts.ts` | +2 |
| `packages/review-editor/components/ReviewSendControl.test.tsx` | **new**, ~180 lines |
| `packages/review-editor/utils/exportFeedback.reviewNote.test.ts` | **new**, ~60 lines |
| `packages/server/review-note-payload.test.ts` | **new**, ~110 lines |
| `packages/review-editor/components/ReviewHeaderMenu.mobile.test.tsx` | ~+30 |
| `AGENTS.md` / `CLAUDE.md` | ~+8 (a "Submit with a note" paragraph under Code Review Flow, matching #1436's) |

**≈ 710 added / ≈ 12 removed across 12 files, 6 of them new. Zero server files touched. Zero `packages/ui` component files touched (one new shortcut scope + one export line).**
