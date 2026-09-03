# Implementation spec — the unified header decision control

Status: implementation spec for approved design. Untracked by convention (do not commit).
Approved artifacts, in force and authoritative over anything restated here:

- `DESIGN_header-states.md` — current-state inventory + the four rules.
- `DESIGN_header-states.html` — current-state reference mockup.
- `DESIGN_header-prototype.html` — **the approved interactive model**. Every label, subtitle,
  confirm string and transition in this spec is read out of `primarySpec()` / `menuSpec()` /
  `openComposer()` / `openConfirm()` in that file (lines 401-456, 617-660, 683-706). Where this
  spec and the prototype disagree, the prototype wins and this spec is wrong.
- `DESIGN_review-send-with-note.md` — the review note transport study (still accurate about
  payloads, archive, and the four consumers; its *container* recommendations are superseded).

Every file:line below was re-read against `main` at `496a1fd1` on 2026-09-01. The design docs'
line numbers had drifted; these have not.

---

## 1. Problem and the approved model

Today the two apps disagree about what "I looked at this" means, both offer buttons in states
where those buttons destroy work, and four dialogs exist to apologise for that. The approved model
replaces the whole cluster with **one adaptive split decision control per header plus a ghost-X
Close**, and holds one hard rule: **Approve/Done and Send Feedback never render side by side.**

| State | Annotate (file / folder / last / url / html / live-app) | Review (agent mode) |
|---|---|---|
| No feedback | `[×] [Done ▾]` | `[×] [Approve ▾]` |
| Feedback present (n) | `[×] [Send Feedback · n ▾]` | `[×] [Send Feedback · n ▾]` |
| Annotate **gate** | maps onto the review row (`Approve ▾` at zero) | — |

The caret carries the alternate decision and the note; choosing a "…with a note" item **morphs the
same popover** into the composer. `Mod+Enter` always equals the visible primary; inside the
composer it fires the composer's labelled action. The left segment never opens a panel and never
changes meaning within a state.

Non-goals, stated so review does not hunt for them: **plan mode is untouched** (the
`ExitPlanMode` approval channel cannot carry side-band feedback); the guides.show viewer, archive
mode, goal-setup mode and the bot-callback header are untouched.

---

## 2. The shared control

### 2.1 Placement — decisive

**`packages/ui/components/DecisionControl.tsx`** (component + `DecisionNoteField` +
`DecisionNoteDialog`), with the pure state→spec mapping in
**`packages/ui/utils/decisionSpec.ts`**. Deliberately **not** added to
`packages/ui/README.md`'s supported imports, `packages/ui/HANDOFF.md`, or the `files` list in
`packages/ui/tsconfig.strict-consumer.json`.

Why `packages/ui` and not somewhere unpublished:

1. It is the only module graph both apps already share. Verified: `packages/review-editor`
   imports nothing from `packages/editor` and vice versa; workspaces are `apps/*` + `packages/*`
   (`package.json:19`), so "a shared spot consumed by both apps without publishing" means creating
   a new workspace package with its own manifest, tsconfig, test and build wiring for one
   component. That cost buys nothing.
2. Its siblings are already there and are already app-shared-but-not-host-surface:
   `components/ToolbarButtons.tsx` (the three buttons this replaces), `components/ActionMenu.tsx`,
   `components/ConfirmDialog.tsx`, `components/ApproveDropdown.tsx`. **None** of them appears in
   `tsconfig.strict-consumer.json:25-63` or in the README's supported-import list.
3. The convention that a `packages/ui` addition needs README + HANDOFF + strict-consumer entries
   is the price of declaring something a **supported host import**, not the price of adding a
   file. We decline to declare it, on purpose: the decision control is session/transport chrome
   (approve/deny/exit against Plannotator's own endpoints, capability adverts from Plannotator's
   own servers), not document UI. The strongest precedent is that `AppHeader.tsx` itself lives in
   `packages/editor/components/`, not in `packages/ui` — the CLAUDE.md tree that says otherwise is
   stale.
4. Does Workspaces benefit? Not today. A host's session decisions are its own outcomes against its
   own backend; there is nothing here it could adopt without also adopting `/api/feedback`,
   `/api/approve` and `/api/exit`. Promotion later is cheap and non-breaking: one README section,
   one HANDOFF note, one line in the strict-consumer `files` list. Nothing in this placement blocks
   it.

Cost accepted: `packages/ui` is published, so the PR that lands this bumps
`packages/ui/package.json` version like any other `ui` change (recent precedent: `496a1fd1`
"bump @plannotator/ui to 0.36.1") and re-runs `bun run --cwd packages/ui smoke:package`
(`.github/workflows/test.yml:44`). No host-facing doc changes, because no supported import is added.

Rejected alternative: keep the branches' two forked controls
(`packages/editor/components/AnnotateSendControl.tsx`,
`packages/review-editor/components/ReviewSendControl.tsx`). Their own module docs already carry the
extraction tripwire, and this design adds the third consumer (the review sidebar's
"+ General comment") that trips it. Forking again would make the "one declarative spec" rule
unenforceable.

Rejected alternative: put `decisionSpec.ts` in `packages/core`. Core is the zero-dep universal
slice shared by `ui` + `shared`; the spec is UI copy, and parking it there would make every label
tweak a `core` publish.

### 2.2 The pure spec (`packages/ui/utils/decisionSpec.ts`)

No React, no DOM, no imports outside `packages/ui/types`. This is what makes the state matrix
testable in the plain `bun test` lane (see §8) and what makes "both apps and both states are data,
not forked components" true rather than aspirational.

```ts
export type DecisionActionId =
  | 'primary'              // the left segment
  | 'note-with-approval'   // "Done with a note…" / "Approve with a note…"
  | 'request-changes'      // "Request changes…"
  | 'note-with-feedback'   // "Send with a note…"
  | 'approve-with-notes'   // review + gate-annotate; capability-gated
  | 'discard-and-finish';  // "Done/Approve, discard n annotations…"

export type DecisionTone = 'success' | 'primary' | 'destructive';

export interface DecisionPrimary {
  id: 'primary';
  label: string;            // 'Done' | 'Approve' | 'Send Feedback'
  shortLabel?: string;      // 'Send' — the lg-breakpoint label
  mobileLabel?: string;     // compact/touch row label
  title: string;            // tooltip / aria description
  tone: Exclude<DecisionTone, 'destructive'>;
  icon: 'check' | 'send';
  count?: number;           // rendered as the inline pill; omitted when 0
}

export interface DecisionComposer {
  title: string;            // popover back-button title, e.g. 'Send with a note'
  actionLabel: string;      // the composer's own button, e.g. 'Send feedback with note'
  tone: Exclude<DecisionTone, 'destructive'>;
  icon: 'check' | 'send';
  placeholder: string;      // 'Add a note...'
}

export interface DecisionConfirm {
  title: string; message: string; confirmText: string;
}

export interface DecisionMenuItem {
  id: Exclude<DecisionActionId, 'primary'>;
  label: string;
  subtitle: string;
  tone: DecisionTone;
  icon: 'check' | 'send';
  dividerBefore?: boolean;
  composer?: DecisionComposer;   // present ⇒ the item morphs the popover
  confirm?: DecisionConfirm;     // present ⇒ the item raises one confirm
}

export interface DecisionSpec { primary: DecisionPrimary; items: DecisionMenuItem[] }

export interface DecisionSpecInput {
  app: 'annotate' | 'review';
  /** Annotate: `gate`. Review: always true — review's primary decision IS approval. */
  gate: boolean;
  /** The count rendered in the pill and interpolated into labels. */
  count: number;
  /**
   * Whether there is anything to send. Deliberately separate from `count`:
   * annotate counts direct edits / saved-file changes / attachments as feedback with count 0
   * (`hasFeedbackContent`, packages/editor/App.tsx:2725).
   */
  hasFeedback: boolean;
  /** Does the runtime deliver feedback on approve? Gates every approve-carrying item. */
  approvalNotesSupported: boolean;
}

export function buildDecisionSpec(input: DecisionSpecInput): DecisionSpec;
```

Resulting matrix (labels and subtitles are the prototype's, verbatim; `n` = `count`):

| app / state | primary | menu items in order |
|---|---|---|
| annotate, no feedback, **no gate** | `Done` (success, check) | `Done with a note…` *(composer: "Done — send note", success)*; ─; `Request changes…` *(composer: "Send as feedback", primary)* |
| annotate, no feedback, **gate** | `Approve` (success, check) | `Approve with a note…` **only when `approvalNotesSupported`**; ─; `Request changes…` |
| annotate, feedback (n) | `Send Feedback` + `n` (primary, send) | `Send with a note…` *(composer: "Send feedback with note")*; ─; `Approve with notes` **gate + capability only**; `Done, discard n annotations…` *(confirm)* — in gate mode `Approve, discard n annotations…` |
| review, no feedback | `Approve` (success, check) | `Approve with a note…` **only when `approvalNotesSupported`** (phase 2; absent in phase 1); ─; `Request changes…` |
| review, feedback (n) | `Send Feedback` + `n` | `Send with a note…`; ─; `Approve with notes` **only when `approvalNotesSupported`**; `Approve, discard n annotations…` *(confirm)* |

**Correction to the design study, load-bearing:** `DESIGN_header-states.md` §3 lists
"…with a note / request changes" for *both* apps at the empty state. For **review**, the
"Approve with a note…" half is undeliverable today — an approve-carrying note is discarded by four
of the runtimes (§6.3). The design's own rule — *"Never render an item that silently drops
content"* — therefore applies to it exactly as it applies to "Approve with notes". In phase 1 the
review empty-state menu carries **only** `Request changes…`. Both items light up together in
phase 2, off the same advert. `approvalNotesSupported` gates every approve-carrying item in the
matrix above; that is the single mechanism, not two.

Copy that is deliberately frozen (mark it as such in the source, per the repo Testing Rules):
`Done`, `Approve`, `Send Feedback`, `Request changes…`, `Approve with notes`, and the confirm's
`Discard & finish` / `Discard & approve`. Everything else (subtitles, tooltips) is free prose and
must not be snapshotted.

### 2.3 The component (`DecisionControl.tsx`)

```ts
export type DecisionHandler = (note?: string) => void;

export interface DecisionControlProps {
  spec: DecisionSpec;
  handlers: Record<DecisionActionId, DecisionHandler>;
  busy: boolean;            // isSubmitting || isExiting || isApproving
  isLoading: boolean;       // spinner on the primary only
  labelBreakpoint?: 'md' | 'lg';   // review passes 'lg' — see §3.2
  /** Rendered as a ConfirmDialog by the host, or by the control? -> by the control. */
  confirmDialog?: React.ComponentType<ConfirmDialogProps>;  // defaults to the ui ConfirmDialog
}
```

Structure — one `relative inline-flex` root:

- **Left segment** — `Button variant={tone === 'success' ? 'success' : 'default'} size="xs"`,
  `className="rounded-r-none border-r-0"`, `iconLeft` from `spec.primary.icon`, responsive label
  spans copied from `FeedbackButton` (`packages/ui/components/ToolbarButtons.tsx:44-49`) so the
  toolbar width below `xl` is unchanged in review. `count` renders as an inline pill after the
  label and is present at every breakpoint (it is the state indicator, not decoration).
  `onClick={handlers.primary}`. **Never opens the popover, in any state.**
- **Right segment** — caret only, `className="rounded-l-none px-1.5"`, `aria-haspopup="menu"`,
  `aria-expanded`, `aria-label="More decisions"`, chevron rotates 180° when open,
  `data-decision-caret="true"`.
- **Popover** — `absolute right-0 top-full z-[70] mt-1.5 w-[22rem] max-w-[calc(100vw-2rem)]
  rounded-lg border border-border bg-popover shadow-xl`, `data-decision-popover="menu" | "composer"`.
  In `menu` state it is `role="menu"` and rows are `role="menuitem"` with roving arrow-key focus
  (Up/Down wrap, Home/End, Enter/Space activate) implemented **in this component**.
- **Rows** reuse `ActionMenuItem` (`packages/ui/components/ActionMenu.tsx:65-100`) with one
  additive prop, `role?: 'menuitem'` (default `undefined`, so `PlanHeaderMenu` and
  `ReviewHeaderMenu` are unchanged). Destructive rows get the existing destructive text token; a
  divider is `ActionMenuDivider` (`ActionMenu.tsx:102-104`).

Behaviour contract:

1. **Morph, not a second popover.** Selecting an item with `composer` replaces the menu's children
   in place (a back button carrying `composer.title`, the textarea, a footer of `submitHint` +
   the labelled action). Height animates; the popover element is not remounted.
2. **Esc ladder.** composer → back to the menu, **draft kept in control state**; menu → close,
   focus returns to the caret; neither open → the event is **not consumed**, so the host app's own
   Escape ladder still runs (review `packages/review-editor/App.tsx:1733-1750`). `stopPropagation`
   is called **only** on the two consuming rungs. This is the review-branch finding that must not
   recur.
3. **Mod+Enter** inside the textarea fires the composer's labelled action. Both apps' global
   listeners already decline text fields (`packages/editor/App.tsx:3856`,
   `packages/review-editor/App.tsx` equivalent), so no global change is needed and it cannot
   double-fire.
4. **Enter is a newline.** Always.
5. **Empty note**: the action stays visually enabled and **refocuses the field** (carried over
   verbatim from `ff873893`); it never submits an empty note.
6. **Items with `confirm`** raise one `ConfirmDialog` (`packages/ui/components/ConfirmDialog.tsx:8-20`)
   and, on cancel, return to the open menu — one decision is still one click away
   (`DESIGN_header-prototype.html:704`).
7. **`busy`** disables both segments and closes an open popover.
8. **No fade.** The branches' last commits (`3ce7f6ab`, `210650b7`) faded and disabled the primary
   while the panel was open (`disabled={disabled || open}` + `opacity-40`). That contract is
   **discarded**: it existed because the branches' panel duplicated the primary's own action. Here
   the popover contains only *alternates*, so the primary keeps its meaning and stays clickable.
9. **Dismissal** is `useDismissablePopover` (§2.4).

### 2.4 Outside-click, including the iframe surfaces

New hook `packages/ui/hooks/useDismissablePopover.ts`:

```ts
useDismissablePopover({ enabled, ref, onDismiss, dismissOnIframeFocus }: {
  enabled: boolean; ref: React.RefObject<HTMLElement | null>;
  onDismiss: () => void; dismissOnIframeFocus?: boolean;
});
```

`pointerdown`-outside + `Escape`, i.e. exactly the effect duplicated today in
`ActionMenu.tsx:24-45` and `ApproveDropdown.tsx:43-58`. **Plus** the explicit iframe strategy this
project owes: on raw-HTML (`srcdoc`) and live-app surfaces the page lives in an iframe, so a click
inside it never produces a `pointerdown` in the parent document and an open popover would hang
over the page. `dismissOnIframeFocus` adds a `window` `blur` listener that, on the next task,
dismisses when `document.activeElement?.tagName === 'IFRAME'`. No bridge protocol change, no
server change, and it works identically on srcdoc and on the live proxy. Precedent for treating
iframe focus as a first-class signal: `packages/ui/components/html-viewer/useHtmlAnnotation.ts:636-637`
and `:740-741` already release iframe focus so parent popovers can take it.

`DecisionControl` passes `dismissOnIframeFocus` whenever the host says the surface is framed
(`htmlSurface` in annotate). Converting `ActionMenu` and `ApproveDropdown` onto the same hook is
listed as its own cleanup step (PR7) so this PR does not silently change the Options menu.

### 2.5 What carries over from the two held branches, and what is discarded

**Carried over verbatim (their reviews proved these clean; only the containers change):**

| From | What | New home |
|---|---|---|
| `origin/feat/annotate-submit-with-note` (`3ce7f6ab`) | the note field itself — `rows={2}`, auto-grow to 144px then scroll, `resize-none`, placeholder `Add a note...`, autofocus on open, key handling | `DecisionNoteField` in `DecisionControl.tsx` |
| same | `commitSubmitNote` — note → `GLOBAL_COMMENT` at submit time, **not** recorded in `annotationHistory` (it lives for one submit) | `packages/editor/App.tsx`, unchanged except the id (§9) and the new `framing` argument (§3.1) |
| same | the one-render deferred submit: commit to state, then submit from a `useEffect` once the note is actually in `annotations` — because the payload builders close over `allAnnotations` | both apps, unchanged |
| same | works on all six annotate surfaces (file, folder, last, url, html, live-app); the strict-gate one-shot composes; archive integration is free | preserved by construction — the control is mounted in the same place for every annotate surface |
| `origin/feat/review-submit-with-note` (`ff873893`) | `commitReviewNote` — note → `scope:'general'` `CodeAnnotation`, no `withPRContext` stamp, `filePath:''`/`0`/`0` sentinels | `packages/review-editor/App.tsx`, unchanged except the id |
| same | the `renderGeneralComments` export path (`packages/review-editor/utils/exportFeedback.ts:251-267`) — already on `main`, nothing to port | — |
| same | the dual-runtime payload test (`packages/server/review-note-payload.test.ts`) | ported as-is; still the right test |
| same | the export tests (`exportFeedback.reviewNote.test.ts`) | ported as-is |
| same | the compact **dialog** pattern (`Dialog`/`DialogContent`, `initialFocus={false}` under compact, `data-pn-mobile-editable`, `data-pn-touch-target`) rather than a textarea inside a scrolling `ActionMenu` popup | `DecisionNoteDialog` in `DecisionControl.tsx` |
| same | the empty-note **no-op + refocus** fix from `ff873893` | §2.3 rule 5 |

**Discarded, with the reason:**

| Discarded | Why |
|---|---|
| `packages/editor/components/AnnotateSendControl.tsx` and `packages/review-editor/components/ReviewSendControl.tsx` as containers | two forks of one control; replaced by `DecisionControl` driven by `buildDecisionSpec` |
| Their **zero-state meaning flip** (at zero the left segment opened the panel instead of sending) | the maintainer's stated confusion; the caret menu replaces it |
| Their **fade contract** (`disabled || open`, `opacity-40`) | §2.3 rule 8 — the panel no longer duplicates the primary |
| The always-visible `Send Feedback` pill at zero annotations | the empty state's primary is `Done`/`Approve`; "a Send button when there is nothing to send" is the thing being deleted |
| `AnnotateNoteSheet` (annotate compact "Quick note" section) | compact gets the full spec-driven decision rows + `DecisionNoteDialog`, not a bolted-on second surface |
| The branches' shortcut scopes (`annotate-note`, `review-note`) as written | replaced by one shared scope (§4). The annotate one also documented `Enter` for a field that only submits on `Mod+Enter` — the exact "bindings must match shipped behaviour" defect this spec forbids |
| The branches' `AGENTS.md` paragraphs | rewritten once, for the unified control |

---

## 3. Per-app wiring

### 3.1 Annotate (`packages/editor`)

**Header.** `packages/editor/components/AppHeader.tsx:312-373` currently holds two forks: the
annotate branch (`:314-330`, `ExitButton` + `{hasAnyAnnotations && <FeedbackButton/>}`) and the
shared Approve cluster (`:341-369`, gated `(!annotateMode || gate)`). After:

```tsx
{annotateMode ? (
  <>
    <ExitButton appearance="ghost" onClick={onAnnotateExit} title={closeTitle} … />
    <DecisionControl spec={decision.spec} handlers={decision.handlers} busy={…} isLoading={isSubmitting} />
  </>
) : (
  <>{/* plan mode: FeedbackButton (:331-339) + Approve cluster (:341-369) — byte-identical */}</>
)}
```

- One new prop `decision: { spec: DecisionSpec; handlers: Record<DecisionActionId, DecisionHandler> }`
  replaces `hasAnyAnnotations` (`:68`, `:167`, `:321`), `annotateApproveLabel` (`:76`, `:175`,
  `:356-357`), `annotateApproveTitle` (`:77`, `:176`, `:358`) and `onAnnotateFeedback`
  (`:101`, `:189`, `:323`) **for annotate mode only**. `showAnnotationsWarning` (`:75`, `:174`)
  stays: its only use is the plan-mode dimmed Approve + tooltip at `:355` / `:360-366`.
- `ExitButton` gains an additive `appearance?: 'pill' | 'ghost'`
  (`packages/ui/components/ToolbarButtons.tsx:108-137`), default `'pill'` so plan mode is
  unchanged. The ghost form is icon-only at every breakpoint and **must keep an `aria-label`** —
  `packages/ui/components/ToolbarButtons.test.tsx:35` pins the default label and that assertion
  must keep passing for the default.
- Per-surface Close titles (prototype `:521-522`): annotate-last
  *"Dismiss without telling the agent"*, file/folder *"Close session without sending"*, review
  *"Close review without feedback"*.
- The HTML/live-app eye/refresh/pen cluster (`AppHeader.tsx:375-393`) is untouched. The control
  sits to its left, exactly where the old buttons were.

**Spec input** (`packages/editor/App.tsx`, next to the existing derivations at `:3496-3503`):

```ts
const decisionSpec = buildDecisionSpec({
  app: 'annotate',
  gate,
  count: feedbackAnnotationCount,          // App.tsx:1918-1922
  hasFeedback: hasFeedbackToSend,          // App.tsx:3496-3498
  approvalNotesSupported,                  // App.tsx:523, set at :3123
});
```

**Deliberate consolidation:** the header's flip predicate becomes `hasFeedbackToSend`, not the
`hasAnyAnnotations || hasDirectEdits || hasSavedFileChanges` expression currently passed at
`App.tsx:5488`. Those two disagree today: after the agent terminal has already taken delivery
(`isCurrentFeedbackDeliveredToAgent`, `:3494`), `hasFeedbackToSend` is false while the header still
shows Send Feedback. One predicate, the one every guard already uses. Call this out in the PR
description — it is a real, intended behaviour change on agent-terminal sessions.

**Handlers.**

| id | annotate handler |
|---|---|
| `primary` | `submitPrimaryDecision()` — **one callback**, used by the button *and* the keyboard (§4): `gate && !hasFeedbackToSend ? handleAnnotateApprove() : handleAnnotateFeedback()`, each still wrapped by `maybeConfirmUnsavedSourceFileEdits(...)` exactly as `App.tsx:3863-3872` does today |
| `note-with-approval` | `commitSubmitNote(text, { framing: 'approval' })` then, on the next render, the primary |
| `request-changes` | `commitSubmitNote(text, { framing: 'change-request' })` then `handleAnnotateFeedback()` |
| `note-with-feedback` | `commitSubmitNote(text, { framing: 'change-request' })` then `handleAnnotateFeedback()` |
| `approve-with-notes` | `handleAnnotateApprove()` (gate + `approvalNotesSupported` only) |
| `discard-and-finish` | after the confirm: `handleAnnotateFeedback({ overrideAnnotations: [], framing: 'approval' })` in non-gate; `handleAnnotateApprove({ overrideFeedback: '' })` in gate |

**`framing` — why it exists.** In non-gated annotate there is no approve channel; every outcome is
one feedback string. Without framing, "Done with a note…" and "Request changes…" would post
byte-identical bodies, which is exactly the silent-ambiguity this design deletes. The prototype
already distinguishes them (`DESIGN_header-prototype.html:421-422` "approval + note as general
comment" vs `:430-431` "note as general comment, no annotations"). Implementation: `framing:
'approval'` prefixes the payload with the same sentence
`buildCompleteAnnotateFeedback` already emits at zero — *"User reviewed the document and has no
feedback."* (`packages/editor/annotateSubmission.ts:130`) — before the note's `## Global comment`
section. One payload builder, one transport, one extra boolean. This is the **only** place a menu
choice changes payload text rather than endpoint; say so in the code comment.

**Gate mode.** Nothing new is needed on the wire: `/api/approve` already accepts
`feedback` + `annotations` + `codeAnnotations` and `buildAnnotateApprovalBody`
(`annotateSubmission.ts:66-88`) already strips them when the transport is incapable. What changes
is that "Approve with Notes" stops being a **relabelled header button plus a confirmation** and
becomes a **menu item**: `getAnnotateApprovalPolicy` (`annotateSubmission.ts:33-64`) and
`showApproveWithNotesConfirmation` (`App.tsx:6238-6252`) are deleted, and `approvalNotesSupported`
feeds `buildDecisionSpec` directly. The confirm went away because it existed to disambiguate a
button whose label had to carry two meanings; the menu row's label + subtitle now carry them, and
nothing is lost by the action (parity with review's approve-with-notes, which the design specifies
carries no confirm). This is one field (`confirm?`) away from being reversed if the maintainer
disagrees.

**HTML / live-app surfaces.** The control mounts identically; the only surface-specific wiring is
`dismissOnIframeFocus` (§2.4). Note in the PR that annotation undo/redo is already unavailable
while focus is inside those iframes (documented limitation in CLAUDE.md) — the popover is a parent
document surface and is unaffected.

**Compact / touch.** `compactReviewActions` (`App.tsx:4990-5046`) today emits the `feedback` row
only when `hasFeedbackContent` (`:5017-5026`), so a compact annotate session with nothing
annotated has **only** "Close session" — the same missing positive outcome as the desktop header,
and the touch surface has no `Mod+Enter` escape hatch. After: the rows are generated from the
spec — one row for `spec.primary` (label `Done` / `Approve` / `Send feedback`, subtitle from the
count) and one row per `spec.items`, with `composer` items opening `DecisionNoteDialog` and
`confirm` items opening the same `ConfirmDialog`. **A visible send action exists in every compact
state**; this is the prevention, not a nicety.

`CompactPlanAction['id']` (`packages/ui/components/PlanHeaderMenu.tsx:42-48`) gains `'note'` and
`'discard-finish'` additively; `CompactPlanReviewAction`
(`packages/editor/components/CompactPlanReview.tsx:4-12`) widens its `Extract<…>` to include them.
`compactPrimaryReviewActionId` (`App.tsx:5085-5091`) collapses to `spec.primary`'s row id.

### 3.2 Review — agent mode (`packages/review-editor`)

**`packages/review-editor/components/AgentReviewActions.tsx` is deleted outright** (all 78 lines).
Its mount at `packages/review-editor/App.tsx:4283-4292` becomes:

```tsx
{!platformMode ? (
  <>
    <ExitButton appearance="ghost" labelBreakpoint="lg"
      onClick={() => totalAnnotationCount > 0 ? setShowExitWarning(true) : handleExit()} … />
    <DecisionControl spec={decisionSpec} handlers={decisionHandlers} busy={busy}
      isLoading={isSendingFeedback || isApproving} labelBreakpoint="lg" />
  </>
) : ( /* platform branch, §3.4 */ )}
```

`labelBreakpoint="lg"` reproduces what all three deleted buttons passed
(`AgentReviewActions.tsx:43`, `:55`, `:66`), so the toolbar does not widen at `md`.

**Spec input** (next to `totalAnnotationCount`, `App.tsx:3466`):

```ts
const decisionSpec = buildDecisionSpec({
  app: 'review', gate: true,
  count: totalAnnotationCount,
  hasFeedback: totalAnnotationCount > 0,
  approvalNotesSupported: reviewApprovalNotesSupported,   // false until phase 2 (§6.4)
});
```

**Handlers.**

| id | review handler |
|---|---|
| `primary` | `submitPrimaryDecision()` = `totalAnnotationCount === 0 ? handleApprove() : handleSendFeedback()` — the same function the keyboard calls (§4) |
| `request-changes` | `commitReviewNote(text)` → deferred effect → `handleSendFeedback()` |
| `note-with-feedback` | identical to `request-changes`; the two differ only by state, never by transport |
| `note-with-approval` | phase 2 only |
| `approve-with-notes` | phase 2 only — `handleApprove({ withAnnotations: true })` |
| `discard-and-finish` | after the confirm: `handleApprove()` (which already sends `annotations: []`, `App.tsx:3546-3550`) |

`handleSendFeedback`'s zero-count guard (`App.tsx:3490-3493`) is deleted: it is unreachable once
no send action is offered at zero, and leaving it would silently swallow a `request-changes`
submission whose note has not yet landed in state.

**Compact / touch.** `compactReviewActions` (`App.tsx:3905-3944`) is regenerated from the spec the
same way annotate's is. `CompactReviewAction['id']`
(`packages/review-editor/components/ReviewHeaderMenu.tsx:27-33`) gains `'note'` and
`'discard-finish'`; `CompactReviewActionIcon` (`:391-408`) gains the two cases. Rows render at
`:159-171` unchanged. The note composer is `DecisionNoteDialog`, never a textarea inside the
`ActionMenu` popup (that popup closes on outside pointerdown and on row click, and the soft
keyboard fights its `max-h` math).

### 3.3 Review sidebar — "+ General comment"

`scope: 'general'` `CodeAnnotation`s already render (`ReviewSidebar.tsx:195-237`, `:470-481`),
badge (`:262-266`), export (`exportFeedback.ts:251-267`, `:324-326`, `:349`, `:382`) and platform
body (`ReviewSubmissionDialog.tsx:147-159`). The only missing piece is a human producer — today the
sole producer is Call Flow (`packages/review-editor/utils/callFlowAnnotations.ts:77-83`).

- New optional prop `onAddGeneralComment?: (text: string) => void` on `ReviewSidebar`.
- Button placement, **both** branches: the "General" section header (`ReviewSidebar.tsx:470-481`)
  must render whenever the callback is present even with `generalAnnotations.length === 0`, **and**
  the total-empty state (`:456-467`, `totalCount === 0`) must carry the same button — otherwise the
  affordance is invisible in precisely the state it is most useful in.
- The composer is `DecisionNoteField` in a small anchored popover — **the third consumer that
  trips the branches' own extraction tripwire**, and the reason `DecisionNoteField` is a separate
  export rather than a private sub-component.
- Unlike the submit note, a sidebar general comment is **durable**: it goes through
  `addCodeAnnotationsWithHistory` (`App.tsx:1942-1953`) so it is undoable, draft-persisted
  (`App.tsx:909-917`) and deletable via the existing `onDeleteAnnotation` (`ReviewSidebar.tsx:36`).
  It is **not** `withPRContext`-stamped, for the reason `DESIGN_review-send-with-note.md` §3.4
  gives: an unstamped annotation passes every PR scope (`utils/annotationScope.ts:10-19`) and so
  survives an in-place PR switch.
- Creating one raises `totalAnnotationCount`, which flips the header control to
  `Send Feedback · n`. That is the design's stated proof that the control is state-driven; it is a
  test (§8).

### 3.4 Platform (PR) mode — reconciliation

Platform mode (`packages/review-editor/App.tsx:4294-4348`) has its own three-button row —
`ExitButton`, a conditional `FeedbackButton` labelled "Post Comments" (`:4306-4318`), and an
`ApproveButton` with a self-approval tooltip (`:4319-4345`) — all routed through
`openPlatformDialog(...)` into `ReviewSubmissionDialog`, which **already** owns a general-comment
textarea whose contents ride the posted review body (`ReviewSubmissionDialog.tsx:68-69`,
`:147-159`).

**Decision: platform mode adopts the control's *shape* in PR6, not in PR3, and never adopts the
note composer.** Rationale:

- The `[Close] [Post Comments] [Approve]` row has the same defect (`FeedbackButton` conditional
  fork at `:4305`, an approve that is offered beside a send), so leaving it forever contradicts
  the one-control rule.
- But its decisions post to GitHub/GitLab, not to `/api/feedback`, and its confirm surface is a
  full dialog with per-target state, retry semantics and an "open PR" toggle. Folding that into
  the caret menu in the same PR as the agent-mode change would make PR3 unreviewable.
- A second note composer must never exist there: the submission dialog's general-comment field is
  the same field, and `buildFileScopedBody` would happily carry a duplicate.

PR6 therefore maps platform mode onto the same `DecisionSpec` with **no `composer` items**:
primary `Post Comments · n` / `Approve`, menu items `Approve with comments…` (opens the existing
`ReviewSubmissionDialog` in `approve` mode) and `Post comments, then…` as needed, with the
self-approval `muted` state preserved. If the maintainer prefers, PR6 can be dropped and platform
mode documented as a permanent exception — but then say so in `AGENTS.md`, because "one decision
control, ever" would no longer be literally true.

---

## 4. State, shortcuts, and `Mod+Enter`

**One primary, one callback.** Each app grows exactly one `submitPrimaryDecision()` callback.
The header's left segment calls it; the global keydown handler calls it; the compact primary row
calls it. Today the two paths are separate code that happens to agree:

- annotate: `packages/editor/App.tsx:3863-3872` (keyboard) vs `handleHeaderAnnotateFeedback`
  (`:4955-4959`) / `handleHeaderAnnotateApprove` (`:4961-4964`) (header).
- review: `packages/review-editor/App.tsx:3820-3826` (keyboard) vs the two inline arrow functions
  at `:4289-4291` (header).

After the change the keyboard branches collapse to `submitPrimaryDecision()` and the header passes
the same reference. "Keyboard and header can never disagree" becomes structural rather than
reviewed.

**Shortcut registry.** The registry entries are documentation only — `usePlanEditorShortcuts`
(`packages/editor/shortcuts.ts:62`) and `useReviewEditorShortcuts`
(`packages/review-editor/shortcuts.ts:108`) are exported and **never called**; dispatch is the
hand-rolled `window` keydown effects above. That does not make the entries optional: they feed the
in-app help modal and the generated `/docs/reference/keyboard-shortcuts` page
(`apps/marketing/src/lib/shortcutReference.ts:1-2`). **Bindings must match shipped behaviour** —
the annotate branch shipped a scope claiming `Enter` for a field that only submits on `Mod+Enter`;
that must not recur.

Changes, landing in the same PR as the behaviour they describe:

- `packages/editor/shortcuts.ts:25-31` `submitPlan` — unchanged (plan mode).
- `packages/editor/shortcuts.ts:32-37` `submitAnnotations` — description becomes
  *"Done / Send feedback — whichever the header shows"* with a hint naming the adaptive primary.
- `packages/review-editor/shortcuts.ts:21-26` `submit` — same treatment.
- **New shared scope** `packages/ui/shortcuts/decisionControl.shortcuts.ts` (shortcuts **root**,
  not `plan-review/` or `code-review/`, because both apps use identical actions and semantics —
  the convention in CLAUDE.md's Keyboard Shortcuts section), id `decision-control`, title
  `Decision control`:
  - `openMenu`: `Alt+Down` on the focused control? **No** — do not invent a chord. Ship only what
    the control actually implements: `submitNote` (`Mod+Enter`, "Send the note with the decision
    you picked", hint "Available while the decision control's note field is open. Enter inserts a
    newline.") and `closeNote` (`Escape`, "Step back to the decision menu, keeping the note").
  - Exported from `packages/ui/shortcuts/index.ts` and added to
    `annotateSettingsShortcutRegistry` (`packages/editor/shortcuts.ts:104-108`) and
    `reviewSettingsShortcutRegistry` (`packages/review-editor/shortcuts.ts`). Not added to
    `planReviewSettingsShortcutRegistry` — plan mode has no such control.
- The two branch scopes (`annotate-note`, `review-note`) are not ported.

Scope ids stay unique and binding tokens stay normalized; `packages/ui/shortcuts.test.ts` already
enforces both.

---

## 5. Deletion / consolidation inventory

Everything below is verified on `main` at `496a1fd1`.

### 5.1 Review: the dimmed-Approve + tooltip + confirm stack

| Delete | Where |
|---|---|
| the whole component | `packages/review-editor/components/AgentReviewActions.tsx:1-78` (file) |
| its import | `packages/review-editor/App.tsx:16` |
| its mount + the two inline decision arrow-functions | `packages/review-editor/App.tsx:4283-4292` |
| the dimmed treatment | `AgentReviewActions.tsx:64` (`dimmed={totalAnnotationCount > 0}`) |
| the hover tooltip ("Your N annotations won't be sent if you approve.") | `AgentReviewActions.tsx:68-74` |
| the "Annotations Won't Be Sent" **approve** confirm | `packages/review-editor/App.tsx:597` (state), `:4980-4994` (dialog) |
| its six modal-suppression references | `App.tsx:3747`, `:3760`, `:3806`, `:3833`, `:3846`, `:3855` |
| the send-at-zero guard | `App.tsx:3490-3493` |

`ApproveButton`'s `dimmed` prop (`packages/ui/components/ToolbarButtons.tsx:68`, `:82`, `:96`)
**survives**: its other consumer is plan mode (`packages/editor/components/AppHeader.tsx:355`),
which is out of scope. Note that in the PR so a reviewer does not chase a "dead prop".

The **exit** warning (`App.tsx:598`, `:4996-5010`) survives unchanged — the ghost X still warns
when content would be lost. That is the design's rule 3.

### 5.2 Review: "No Annotations" — a partial deletion, not a full one

`DESIGN_header-states.md` §3 lists this dialog as deleted. It must not be: the dialog
(`App.tsx:403` state, `:4971-4977`) has **two** callers, and only one goes away.

- `handleSendFeedback` (`:3490-3493`) — deleted (see 5.1).
- `handleCopyFeedback` (`:3471-3474`) — **kept**. It backs the standalone (no-origin) header's
  `[Copy Feedback]` button (`App.tsx:4350-4360`), which is a different surface with no decision
  control at all, and its message ("There's nothing to copy.") is already copy-specific.

### 5.3 Annotate: the zero-state keyboard-only silent submit

`packages/editor/App.tsx:3863-3872` is the only way today to record "I reviewed this and have no
feedback" — an invisible `Mod+Enter`. It becomes the `Done` button's payload, **byte-identical**:
`POST /api/feedback` with `feedback` = the string `buildCompleteAnnotateFeedback` produces at zero
(`annotateSubmission.ts:124-130`: *"User reviewed the document and has no feedback."*),
`annotations: []`, `codeAnnotations: []`, plus `draftGeneration` and the message scope. Not a new
endpoint, not a new body — see §6.1 for why that matters to exit codes.

### 5.4 Annotate: the approve-with-notes apparatus

| Delete | Where |
|---|---|
| `AnnotateApprovalPolicy` + `getAnnotateApprovalPolicy` | `packages/editor/annotateSubmission.ts:33-64` |
| its call | `packages/editor/App.tsx:3499-3503` |
| `requestAnnotateApprove`'s policy/confirm branches | `App.tsx:3736-3747` (collapses to a direct `handleAnnotateApprove()` call from the menu handler) |
| `showApproveWithNotesConfirmation` state + dialog | `App.tsx` (state, declared with the other dialog flags), `:6238-6252` |
| its five suppression references | `App.tsx:3829`, `:3901`, `:4840`, `:4866`, and the keydown guard list |
| `exitWarningAction`'s `'approve'` half | `App.tsx:432` (union narrows to `'close'`), `:3737-3739` (the setter), `:6262`, `:6268-6272` (the ternaries) |
| `handleHeaderAnnotateApprove` | `App.tsx:4961-4964` |
| the annotate half of the shared Approve cluster | `packages/editor/components/AppHeader.tsx:341-369` — the `(!annotateMode || gate)` gate and the three `annotateMode ? …` ternaries at `:356-358` |
| header props `annotateApproveLabel` / `annotateApproveTitle` | `AppHeader.tsx:76-77`, `:175-176`, `:356-358`; `App.tsx:5496-5497` |

`buildAnnotateApprovalBody` (`annotateSubmission.ts:66-88`) **stays** — it is the capability-aware
body shaper and is still exactly right.

### 5.5 The `FeedbackButton` conditional-render forks

- `packages/editor/components/AppHeader.tsx:321-330` — `{hasAnyAnnotations && <FeedbackButton …/>}`.
- `packages/review-editor/components/AgentReviewActions.tsx:46-57` — `{hasAnnotations && …}`.
- Remaining after this project: the platform-mode fork at `packages/review-editor/App.tsx:4305-4318`
  (PR6 or documented exception, §3.4) and plan mode's unconditional `FeedbackButton`
  (`AppHeader.tsx:331-339`, out of scope).

### 5.6 The four guard/dead-end dialogs the study named — final disposition

| Dialog | Location | Disposition |
|---|---|---|
| "Annotations Won't Be Sent" (approve flavour, review) | `review-editor/App.tsx:4980-4994` | **deleted** — replaced by the discard-item confirm |
| "Annotations Won't Be Sent" (close flavour, review) | `review-editor/App.tsx:4996-5010` | **kept** — the ghost X still warns |
| "No Annotations" | `review-editor/App.tsx:4971-4977` | **kept for the copy path**, its send caller deleted (5.2) |
| "Add Feedback First" | `editor/App.tsx:6173-6183`, sole trigger `:4921` inside `handleHeaderFeedback` (`:4915-4927`) | **kept, deferred.** Verified: `setShowFeedbackPrompt(true)` is called from exactly one place, and that place is the **plan-mode** `onFeedback` handler. It is not reachable in annotate mode, so deleting it here would be deleting plan-mode behaviour. It dies when plan mode adopts the control; note it in the follow-up issue. |
| "Feedback Won't Be Sent" (annotate, approve flavour) | `editor/App.tsx:6255-6276` with `exitWarningAction === 'approve'` | **approve half deleted** (5.4); close half kept |
| "Approve with Notes?" (annotate gate) | `editor/App.tsx:6238-6252` | **deleted** (5.4) |

Net: the only confirm the new model raises is the one on an explicit
`Done/Approve, discard n annotations…` menu item, plus the pre-existing close-with-content warning.

### 5.7 Now-dead exports and duplicated effects

- `AgentReviewActions` — file deleted; no other importer (verified).
- `getAnnotateApprovalPolicy`, `AnnotateApprovalPolicy` — deleted; no other importer.
- The pointerdown+Escape effect is currently written three times:
  `packages/ui/components/ActionMenu.tsx:24-45`, `packages/ui/components/ApproveDropdown.tsx:43-58`,
  and `QuickLabelDropdown.tsx`. PR7 converts them onto `useDismissablePopover` (§2.4). Not in the
  adopting PRs — a shared-primitive rewrite must be reviewable on its own.

---

## 6. Server / runtime analysis

### 6.1 Zero-server-change flows — verified on both runtimes

**Send-with-note, request-changes-at-zero, and Done-at-zero all POST `/api/feedback` with a body
the servers already accept.** Verified:

- Review Bun handler `packages/server/review.ts:3381-3419`: the body is a bare `as` cast
  (`:3383-3389`), `annotations` is `unknown[]`, read only for `.length` (`:3400`) then forwarded
  verbatim to `archiveReviewSubmission` (`:3401-3405`) and `resolveDecision` (`:3407-3412`). No
  schema, no whitelist. Pi mirror: `apps/pi-extension/server/serverReview.ts:3359-3388`.
- Annotate Bun handler `packages/server/annotate.ts:1212-1252`: same shape; `feedback` and
  `annotations` are passed through `persistSubmittedDecision` (`:429-459`), which defensively
  coerces (`:436-437`) rather than validating. Pi mirror:
  `apps/pi-extension/server/serverAnnotate.ts:1111-~1140`.
- Adding one more object to the `annotations` array is invisible to every handler on both
  runtimes. **No server file is touched by PRs 1-4.**

**Annotate `Done` keeps `/api/feedback`, deliberately.** `handleAnnotateFeedback`
(`packages/editor/App.tsx:3645-3698`, the POST at `:3679`) is what `Mod+Enter` posts today, and
`formatAnnotateOutcome` (`apps/hook/server/annotate-output.ts:38-66`) branches on the decision
shape: a `feedback` outcome prints the feedback string in plain mode (`:65`) and emits
`{"decision":"annotated"}` under `--json` (`:59-62`), while an `approved` outcome prints
`APPROVED_PLAINTEXT_MARKER` (`:64`) and, under a strict gate, **exits 0 instead of 1**. Routing
`Done` through `/api/approve` in a non-gated session would therefore change plain-mode output and
strict-gate exit codes for every existing caller. It must not. In **gate** mode the primary at zero
is `Approve` and does post `/api/approve` — which is precisely what `Mod+Enter` does today
(`App.tsx:3864-3868`).

### 6.2 How each decision lands in the archive

Decision kinds are `packages/shared/feedback-archive.ts:75-81`
(`approved | approved-with-notes | denied | feedback | lgtm | dismissed`).

| Action | Endpoint | Archived as |
|---|---|---|
| annotate `Done` (no gate, zero) | `/api/feedback` | **`feedback`**, body = *"User reviewed the document and has no feedback."* (`annotate.ts:448-451`, `hasContent` true because the sentence is non-empty). It also writes the #678 durable submission record for single local files (`annotate.ts:447-457`). |
| annotate `Done with a note…` / `Request changes…` / `Send with a note…` | `/api/feedback` | `feedback` |
| annotate gate `Approve` (zero) | `/api/approve` | **`approved`** (`annotate.ts:448-451`, `hasContent` false) |
| annotate gate `Approve with notes` | `/api/approve` | `approved-with-notes` |
| annotate ghost X | `/api/exit` | `dismissed` (hardcoded, `annotate.ts:1148`) |
| review `Approve` / `Approve, discard n…` | `/api/feedback` `approved:true` | **`approved-with-notes`** — see the bug below |
| review `Send Feedback` / `Request changes…` / `Send with a note…` | `/api/feedback` `approved:false` | `feedback` |
| review ghost X | `/api/exit` | `dismissed` (`review.ts:3374`) |

**Two archive facts worth recording, neither of which this project's phases 1-4 change:**

1. **The `lgtm` decision is unreachable in production.** `review.ts:3404` computes
   `approved ? (hasContent ? "approved-with-notes" : "lgtm") : "feedback"`, but the only client
   that sends `approved: true` is `handleApprove`, which always sends the non-empty placeholder
   `'LGTM - no changes requested.'` (`packages/review-editor/App.tsx:3549`, whose own comment says
   the string is "unused — integrations branch on `approved` flag"). So `hasContent` is always
   true and a bare LGTM archives as `approved-with-notes` with the placeholder as its body, plus a
   sidecar file. Confirms `DESIGN_review-send-with-note.md` §4.2. **Fixed in phase 2**, where
   dropping the placeholder is required anyway (§6.4).
2. **Annotate's positive finish is inconsistent across gate modes:** the same human action
   ("reviewed, nothing to say") archives as `feedback` without a gate and `approved` with one.
   That is a consequence of the transports, not of this design, and phase 1 preserves it byte for
   byte. Worth an issue; not worth a payload change inside a header PR.

`normalizeAnnotation` (`feedback-archive.ts:263-297`) copies a fixed allowlist that does **not**
include `scope` (verified) — a review general comment archives as
`{ id, type: "comment", text, author }` with no indication it was review-level. Adding
`scope?: string` is additive and sanctioned by the "fields are added, never repurposed" contract
(`feedback-archive.ts:30-31`), and would need the Pi vendored copy regenerated. Open question 2.

### 6.3 The consumers that discard `result.feedback` on approve

`waitForDecision()` resolves `{ approved, feedback, annotations, agentSwitch?, exit? }`
(`packages/server/review.ts:225-231`). Four **direct** consumers throw the feedback away on the
approved branch:

| # | Consumer | Line | Behaviour |
|---|---|---|---|
| 1 | Claude Code CLI `plannotator review` | `apps/hook/server/index.ts:1079-1093` | `else if (result.approved) console.log(getReviewApprovedPrompt(detectedOrigin))` — `result.feedback` never printed |
| 2 | OpenCode native | `apps/opencode-plugin/commands.ts:173`, `:195-199` | `result.approved ? getReviewApprovedPrompt("opencode") : …` |
| 3 | OpenCode CLI bridge | `apps/opencode-plugin/cli-bridge.ts:569-595` | returns `getReviewApprovedPrompt("opencode")` on approve — note this discards the output of a CLI that does **not** discard (`apps/hook/server/index.ts:1856` emits `feedback` unconditionally) |
| 4 | Pi | `apps/pi-extension/index.ts:660-680` | sends `getReviewApprovedPrompt("pi", loadConfig())` then `return`s |

Two more read a review decision and do **not** discard: `apps/review/server/index.ts:79-96` (the
standalone dev server, prints `feedback` always) and the `opencode-review` CLI branch
(`apps/hook/server/index.ts:1809-1856`) feeding consumer 3. The amp and droid plugins are **not**
independent decision points — `apps/amp-plugin/plannotator.ts:344-352` and
`apps/droid-plugin/commands/plannotator-review.js` shell out to `plannotator review` and relay its
stdout, so they inherit consumer 1's behaviour and need no change of their own.

### 6.4 Phase 2 — "Approve with notes" delivery (its own PR, two-runtime law)

Three changes that must land **together**, because a consumer that starts printing
`result.feedback` on approve would, against today's client, append the literal string
`LGTM - no changes requested.` to every approval:

1. **Client** — `handleApprove` (`packages/review-editor/App.tsx:3540-3565`) stops sending the
   placeholder: `feedback: noteText ?? ''` and, for `approve-with-notes`, the live
   `allAnnotations` instead of `[]`. This is also what finally makes the `lgtm` archive decision
   reachable and stops a bare approval writing a sidecar.
2. **Consumers** — the four call sites in §6.3 print/send the approved prompt **and then** the
   note when `result.feedback.trim()` is non-empty. Both runtimes and every plugin path
   (`hook`, `opencode` native, `opencode` bridge, `pi`); `apps/review/server/index.ts` already
   complies.
3. **Capability advert** — mirroring `approvalNotesSupported`, whose full mechanism is:
   `supportsAnnotateApprovalNotes` (`apps/hook/server/annotate-output.ts:21-24`,
   `gate && json && !hook`) → passed at `apps/hook/server/index.ts:1293`, `:1540`, `:2087`
   (OpenCode advertises per-session at `commands.ts:387`, `:505`; Pi unconditionally at
   `plannotator-browser.ts:717`) → server option `packages/server/annotate.ts:123`, defaulted at
   `:244`, echoed into both `/api/plan` bodies (`:717`, `:769`; Pi `serverAnnotate.ts:227`, `:731`,
   `:786`) → client `packages/editor/App.tsx:523`, `:3123`.
   The review mirror needs: a `supportsReviewApprovalNotes(origin)` resolver (review has no
   `--gate/--json/--hook` triad, so this is genuinely new logic keyed on the **origin's consumer**,
   not on flags); a `startReviewServer` option; the field echoed on `/api/diff`
   (`packages/server/review.ts`, the `Response.json` at ~`:2029`) **and** on the three other
   diff-payload responses the client may receive later — `/api/diff/switch`, `/api/pr-diff-scope`,
   `/api/pr-switch` — or the advert silently disappears after a diff switch; and the identical
   change in `apps/pi-extension/server/serverReview.ts`.

Until phase 2 ships for a given origin, `approvalNotesSupported` is false there and **both**
approve-carrying menu items are absent. The reviewer of phase 2 should hunt one thing above all:
an origin whose advert says "capable" while its consumer still discards.

---

## 7. Migration plan — ordered, independently shippable PRs

**PR1 — primitives (nothing mounted).**
`packages/ui/utils/decisionSpec.ts`, `packages/ui/components/DecisionControl.tsx`
(`DecisionControl` + `DecisionNoteField` + `DecisionNoteDialog`),
`packages/ui/hooks/useDismissablePopover.ts`, `ExitButton` `appearance` prop,
`ActionMenuItem` `role` prop, the new shortcut scope file, `packages/ui` version bump.
*Isolated review should hunt:* the spec matrix against `DESIGN_header-prototype.html:401-456`
(every label, subtitle, confirm string); that `decisionSpec.ts` imports nothing from React or the
DOM; that the Escape ladder consumes the event on exactly two rungs; that the primary never opens
the popover; that `ExitButton`/`ActionMenuItem` defaults are byte-identical for existing callers.

**PR2 — annotate adopts.** Header, gate mode, HTML/live-app, compact; the §5.3/§5.4/§5.5
deletions; `submitPrimaryDecision`; shortcut description updates; `AGENTS.md` + `CLAUDE.md`
paragraph.
*Hunt:* that `Done` posts the byte-identical legacy payload (§5.3); that gate mode's
`Approve`/`Approve with notes` still respects `approvalNotesSupported` through
`buildAnnotateApprovalBody`; that the header predicate change from `hasFeedbackContent` to
`hasFeedbackToSend` is intended and correct on agent-terminal sessions; that compact has a visible
positive action at zero; that the six annotate surfaces all mount the control.

**PR3 — review agent mode adopts.** Delete `AgentReviewActions` and the §5.1 stack; wire the
handlers, the compact rows and the note transport; port the branch's payload/export tests.
*Hunt:* that Approve and Send Feedback never render together in any state (the invariant test);
that the "No Annotations" dialog still serves the copy path (§5.2); that Escape inside the
composer does not also collapse the file tree or close the sidebar (`App.tsx:1733-1750`); that the
toolbar does not widen at `md` (`labelBreakpoint="lg"`).

**PR4 — review sidebar "+ General comment."** Including the empty-state placement and the durable
(history-recorded, non-PR-stamped) annotation shape.
*Hunt:* reachability at `totalCount === 0`; that the new annotation flips the header control; that
it survives a PR switch (`annotationScope.ts:10-19`).

**PR5 — phase 2 delivery (server + four consumers + client).** §6.4, two runtimes.
*Hunt:* an origin advertised capable whose consumer still discards; the placeholder removal's
archive consequences (`lgtm` becomes reachable; bare approvals stop writing sidecars); that the
advert survives `/api/diff/switch` and the two PR endpoints.

**PR6 — platform (PR) mode.** §3.4. Droppable; if dropped, document the exception.

**PR7 — consolidation + docs.** `ActionMenu` / `ApproveDropdown` / `QuickLabelDropdown` onto
`useDismissablePopover`; `tests/UI-TESTING.md` flow updates (its review flow at `:187-190` asserts
a "Send Feedback" button that no longer exists at zero); the follow-up issue for plan mode +
"Add Feedback First".
*Hunt:* that the Options menus behave identically before and after the hook swap.

---

## 8. Test plan

Per the repo Testing Rules: every test names the regression it guards; no incidental prose is
snapshotted; nothing mutates `process.env`, `~/.plannotator` or globals at module scope.

**A. Pure — `packages/ui/utils/decisionSpec.test.ts`. No DOM, so it runs in the plain `bun test`
lane and can never silently skip.** This is the main safety net and the reason the spec is pure.

1. The full state matrix: for each of the six rows in §2.2, `buildDecisionSpec` returns the
   expected primary id/label/tone and the expected ordered item ids. *Guards the model itself.*
2. **"Approve and Send Feedback never render together":** for every input combination, the primary
   label and every item label never both contain an approve verb and a send verb in a way that
   puts them in the header — concretely, `spec.primary.label` is never `Send Feedback` while any
   item id is `primary`, and no spec ever yields two primaries. *Guards the maintainer's hard rule.*
3. `approvalNotesSupported: false` ⇒ **no** item with id `approve-with-notes` **or**
   `note-with-approval` in review, in either state. *Guards rendering an item that silently drops
   content.*
4. Every item with a destructive outcome (`discard-and-finish`) carries a `confirm`. *Guards a
   refactor that drops the one remaining guard dialog.*
5. Counts: `count: 0` ⇒ `primary.count` undefined; `count: 3` ⇒ `3` and the discard label
   interpolates `3`. *Guards a stale count in the label after an annotation is deleted.*
6. Frozen-copy assertions for the five deliberately frozen strings, each with a comment marking it
   as a maintainer-approved freeze, not a snapshot.

**B. DOM — `packages/ui/components/DecisionControl.test.tsx`.** `describe.skipIf(!hasDom)`,
`createRoot` + `act`, precedent `packages/ui/components/ActionMenu.test.tsx:42-53` and
`AnnotationToolbar.commentOnly.test.tsx`. **Must be appended to the
`Run UI seam-contract + DOM tests` step in `.github/workflows/test.yml` (the explicit file list
ending at `:179`) or it silently skips forever** — `packages/ui/test-setup/happy-dom.ts:6` only
registers the DOM when `DOM_TESTS=1`.

7. The left segment calls `handlers.primary` and **never** opens the popover, in both states.
   *Guards the in-flight branches' zero-state flip coming back.*
8. `Enter` is a newline; `Mod+Enter` (both `metaKey` and `ctrlKey`) fires the composer action once
   with the trimmed text. *Guards a revert to a one-line field.*
9. `Escape` in the composer returns to the menu and **keeps** the text; `Escape` in the menu closes
   and does not propagate; `Escape` with nothing open **does** propagate. *Guards both throwing
   away a half-typed note and hijacking the host app's Escape ladder.*
10. The composer action with an empty/whitespace note does not submit and refocuses the field.
11. A `confirm` item raises the dialog and only calls its handler after confirmation; cancel
    returns to the open menu.
12. Blur to an iframe dismisses when `dismissOnIframeFocus` is set, and does not when it is not.
    *Guards the HTML/live-app hang-over-the-page defect.*
13. Roving focus: Down/Up move between `role="menuitem"` rows and wrap.

**C. Handler exhaustiveness — `packages/editor/decisionHandlers.test.ts` and
`packages/review-editor/decisionHandlers.test.ts` (pure).** For every input in the matrix, the
app's handler map has an entry for `primary` and for every id the spec can emit. *Guards a menu
item with no handler — the failure mode that the missing typecheck (§9) would otherwise catch.*

**D. Payload / export / archive.** Port the review branch's three files as-is
(`packages/server/review-note-payload.test.ts` — both runtimes, note survives `waitForDecision`
unmodified and archives as `feedback` with the note in `counts.annotations`;
`packages/review-editor/utils/exportFeedback.reviewNote.test.ts`), and add the annotate analogues:

14. `Done` at zero posts the byte-identical legacy body (`feedback` = the "no feedback" sentence,
    `annotations: []`). *Guards the one behaviour every existing CLI consumer and exit code
    depends on (§6.1).*
15. `Request changes…` at zero posts `approved: false` with exactly one `GLOBAL_COMMENT` and no
    other annotations; `Done with a note…` posts the same array with the approval framing line.
    *Guards the two menu items collapsing into one payload.*

**E. Compact.** Extend `packages/review-editor/components/ReviewHeaderMenu.mobile.test.tsx` and
`packages/editor/components/CompactPlanReview.test.tsx`:

16. At zero annotations the compact menu contains a visible positive decision row. *Guards the
    exact regression this project exists to fix, on the surface that has no `Mod+Enter`.*

**F. Integration.** The annotate branch's `packages/editor/App.submitNote.test.tsx` is the only
existing test that mounts an App; port its six cases onto the new control (the review App is not
mountable — dockview + the Pierre worker pool + the Shiki bundle — which is why C and D carry the
review side).

17. Adding a general comment in the review sidebar flips the header control to `Send Feedback · 1`.
    *Guards the state-driven claim.* Component-level (sidebar + a spec assertion), not App-level.

Manual QA line for `tests/UI-TESTING.md`: both apps, both states, desktop and a real phone;
Escape from the composer does not collapse the file tree or close the sidebar; an open popover on
an HTML annotate session dismisses when you click the framed page.

---

## 9. Risks, and the review findings that must not recur

| Finding (from the two branch reviews) | Prevention in this spec |
|---|---|
| Compact/touch surfaces shipped without a visible send action (`Mod+Enter`-only; touch has no Cmd key) | §3.1 / §3.2 generate compact rows from the same spec, so a state that has a primary on desktop has a row on touch by construction; test E16 |
| Shortcut scope bindings that did not match shipped behaviour (they feed the help modal and the marketing docs) | §4 ships one scope describing only the two chords the control implements; the two stale branch scopes are not ported |
| New DOM test files not registered in `.github/workflows/test.yml` silently skip | §8B names the step and the line; the bulk of the coverage is deliberately in the **pure** lane (§8A, §8C) which cannot skip |
| On HTML/live-app surfaces iframe clicks never reach the parent, so outside-click close has no strategy | §2.4 `dismissOnIframeFocus`; test B12 |
| Note ids built from `Date.now()` | both branches used `global-note-${Date.now()}` / `review-note-${Date.now()}`. Use `crypto.randomUUID()` (available in every browser the app targets and in Bun) with a stable prefix: `global-note-${crypto.randomUUID()}`, `review-note-${crypto.randomUUID()}`. Two notes committed in the same millisecond (paste + submit, or an external annotation arriving concurrently) would otherwise collide, and the deferred-submit effect keys on the id. Also worth fixing the same pattern at `packages/ui/components/Viewer.tsx:915` (`global-${Date.now()}`) — **in PR7, not inline.** |

**Pre-existing gap this project files rather than fixes: neither app package is typechecked.**
`bun run typecheck` (`package.json:37`) runs nine projects; `packages/editor` has **no
`tsconfig.json` at all**, and `packages/review-editor/tsconfig.json` exists but is referenced by
nothing (it also lacks `types`, so it fails on `process`/`bun:test` before reaching real errors).
Measured with a `packages/ui`-shaped config (`types: ["bun"]`, non-strict): **`packages/editor`
40 errors (20 outside test files); `packages/review-editor` 50 errors (24 outside test files)** —
`import.meta.env`, a `PRSwitchResponse` handler mismatch, several `string | null` → `string |
undefined` arguments, and `{ id }[]` returned into `setState<CodeAnnotation[]>` at
`review-editor/App.tsx:611-631`. That is a real cleanup, unrelated to the header, and folding ~44
type fixes into a UI redesign would make every PR above unreviewable.

Decision: **file it** (issue: "typecheck packages/editor and packages/review-editor", with these
numbers and the exact config used), and mitigate in-scope instead — the shared types live in
`packages/ui`, which **is** typechecked, and test C makes the untyped half of the contract (each
app's handler map covering the spec's ids) a runtime assertion. If the maintainer would rather fix
it first, it is a clean PR0 and this plan is unchanged.

Other risks:

- **Two clicks for approve-despite-notes.** Accepted in the design (§4 of the study). If it grates,
  the cheapest reversal is a `defaultOpen` on the caret, not a second header button.
- **Deleting the annotate gate's "Approve with Notes?" confirm** (§5.4) removes a maintainer-added
  safeguard. It is one `confirm?` field away from being restored, and the item's label + subtitle
  now carry what the dialog said.
- **`packages/ui` version churn.** Four of the seven PRs touch `packages/ui`. Batch the bump into
  PR1 and PR7 where possible.

---

## 10. Open questions for the maintainer

1. **Platform (PR) mode** (§3.4): adopt the control's shape in PR6, or declare platform mode a
   permanent exception to "one decision control, ever" and document it? Its decisions post to
   GitHub/GitLab through a dialog that already owns a general-comment field, so it is the one
   surface where the rule is arguably not the right rule.
2. **`scope` in the archive** (§6.2): should `normalizeAnnotation`
   (`packages/shared/feedback-archive.ts:263-297`) gain `scope?: string` so a review-level general
   comment is distinguishable from a line comment in `index.jsonl`? Additive and sanctioned by the
   field contract at `:30-31`; it also means regenerating the Pi vendored copy. Say the word and it
   rides with PR4, otherwise general comments archive without their scope.
3. **Annotate's two positive finishes** (§6.2): the same human action archives as `feedback`
   without a gate and `approved` with one. Phase 1 preserves both byte for byte. Do you want a
   follow-up that reconciles them (which needs either a new endpoint or an additive
   `positiveFinish` flag on `/api/feedback`, both runtimes), or is the transport-shaped difference
   the honest record?
