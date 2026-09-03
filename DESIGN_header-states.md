# Header / action-state study: annotate + code review

Companion mockups: `DESIGN_header-states.html` (current-state reference; dark, self-contained).
Interactive proposal prototype (every transition clickable): `DESIGN_header-prototype.html`.
Everything below is read from the code on `main` plus the two in-flight branches; file references
are exact.

---

## 1. Current-state inventory

### Shared primitives (`packages/ui/components/ToolbarButtons.tsx`, `ui/button.tsx`)

| Button | Variant | Look | Notes |
|---|---|---|---|
| `ExitButton` | `secondary` + forced `bg-muted text-muted-foreground` | muted gray pill, label **Close** (X icon below breakpoint) | title "Close session without sending feedback" |
| `FeedbackButton` | `outline` | bordered, Send icon, **Send Feedback** | label hidden below `md`/`lg` (icon-only) |
| `ApproveButton` | `success` | solid green, Check icon, **Approve** (mobile "OK") | `dimmed` → `bg-success/50 text-success-foreground/70` |

All `size=xs`: h-7 (28px), px-2.5, rounded-md, text-[13px] font-medium.

### Surface x state x visible action buttons

| Surface | Session state | Action cluster (left→right) | Guards / notes |
|---|---|---|---|
| **Annotate — file** (no gate) | 0 annotations | **[Close]** | No positive submit exists in the header. `Mod+Enter` still fires `handleAnnotateFeedback()` → sends "User reviewed the document and has no feedback." (`App.tsx:3863-3871`) — a gesture with no visible button. |
| | annotations / edits present | **[Close] [Send Feedback]** | `hasAnyAnnotations` also counts direct edits, code/editor/linked-doc annotations, attachments, saved file changes (`App.tsx:1900`, header prop `:5489`). Close → "Feedback Won't Be Sent" confirm (`:6256-6276`). |
| **Annotate — folder** | same as file | same | Only differences: export heading "Folder Feedback", compact title "Choose a file", per-file history. |
| **Annotate — last (message)** | same as file | same | Close = dismissal (`/api/exit` → decision record `dismissed`, agent gets nothing; `packages/server/annotate.ts:1142-1151`). No agent terminal. Multi-message picker changes counts, not chrome. |
| **Annotate — HTML / live-app** | any | adds **eye / refresh / pen** cluster after the divider (`AppHeader.tsx:381-393`) | Document-surface controls, orthogonal to session actions. Refresh: local rendered HTML only. |
| **Annotate — gate** (context only) | 0 feedback | [Close] [Approve] | `Mod+Enter` → Approve. |
| | feedback present | [Close] [Send Feedback] [Approve / **Approve with Notes**] | `getAnnotateApprovalPolicy` (`packages/editor/annotateSubmission.ts`): capable transports get Approve-with-Notes + confirm; incapable ones get the "Feedback Won't Be Sent" warning re-used for Approve. |
| **Review — agent mode** | 0 annotations | **[Close] [Approve]** | `AgentReviewActions.tsx:37-76`. Approve POSTs `approved: true` immediately. Send Feedback hidden (the maintainer's "why is Send Feedback there" complaint describes the released build; #523 already made it conditional on `main` — but Close+Approve still disagrees with annotate's Close-only). |
| | annotations present | **[Close] [Send Feedback] [Approve (dimmed)]** | Approve dims to 50% + hover tooltip "Your N annotations won't be sent"; Approve and Close both route through the "Annotations Won't Be Sent" confirm (`review App.tsx:4980-5010`). Approve genuinely discards (`handleApprove` sends `annotations: []`). |
| | keyboard | `Mod+Enter` → Send Feedback if N>0 else Approve (`:3820-3826`) | Adaptive keyboard, non-adaptive buttons. |
| **Review — no origin** (standalone) | any | **[Copy Feedback]** | The only surface where copy is a header action; in agent mode copying lives in the export modal. |

Dead-end dialogs that exist only because buttons are offered in the wrong state: review "No
Annotations" (`App.tsx:4972-4977`), plan-mode "Add Feedback First" (`editor App.tsx:6174-6183`).

### In-flight branches (context, not settled)

`feat/annotate-submit-with-note` / `feat/review-submit-with-note`: an always-visible split pill
**[Send Feedback | v]**. Caret opens an anchored composer ("Add a note...", action **Send with
additional feedback**, Mod+Enter submits, Esc keeps the draft, empty note refocuses). The note
materializes as a `GLOBAL_COMMENT` (annotate) / `scope:'general'` CodeAnnotation (review) and rides
the normal `/api/feedback` POST — **no server change**. Review adds a compact dialog variant. With
zero feedback the *left segment stops sending and opens the panel instead*.

Verdict: the composer, the note-as-annotation transport, the "two distinct buttons" rule, and the
compact dialog are keepers. Two flaws: (a) the pill re-introduces a Send button when there is
nothing to send — the exact confusion the maintainer named; (b) the left segment's meaning flips
with state, violating "no button whose meaning changes silently".

---

## 2. The problems, precisely

1. **The two apps disagree at the empty state.** Annotate: `[Close]` only — no positive outcome.
   Review: `[Close] [Approve]`. Same user, same mental task ("I looked at the agent's work"),
   different affordances.
2. **Annotate has no visible "that's fine" gesture, but a hidden one.** `Mod+Enter` at zero
   annotations submits a positive "no feedback" record; no button does. Users asking for
   "that's fine & submit" on `/plannotator-last` are asking for a button that already exists
   server-side.
3. **Review's Approve is a trap when feedback exists.** Dimmed + tooltip + confirm — three layers
   of apology for a button that discards work. Meanwhile "approve but carry my notes" is a real
   outcome the annotate gate already models (`Approve with Notes`).
4. **No human overall-comment path in review.** The sidebar renders General annotations but only
   tools create them; the verbatim workaround is "don't Send, Copy manually".
5. **Guard dialogs as architecture.** Four dialogs ("No Annotations", "Add Feedback First",
   "Annotations Won't Be Sent" x2 flavors) exist to patch state/button mismatches.
6. **Keyboard and header can disagree.** `Mod+Enter` re-targets silently; the header shows two or
   three same-weight buttons with no promoted primary.

---

## 3. Recommendation — one decision control, one decision surface

Maintainer constraint (adopted as a hard rule): **Approve and Send Feedback are never both visible
as header buttons.** The alternate decision lives in the dropdown, not the header.

Four rules, identical in both apps (and, later, plan mode):

1. **One decision control, ever.** A single split pill in a single slot. The left segment is the
   state's primary and always does exactly what its label says, in one click:
   - *Nothing to send* → **Done** (annotate) / **Approve** (review), solid success green.
   - *Feedback present* → **Send Feedback · n**, solid primary with the count inline.
   The flip is state-driven (an annotation appearing/disappearing) and mirrored by the visible
   count; the left segment never opens a panel — that was the in-flight pill's zero-state flaw.
2. **The caret carries the alternate decision(s) and the note — never the header.** The caret
   opens a small action menu; each state's menu offers the *opposite* decision, so nothing is
   unreachable:
   - Empty state, `Done ▾` / `Approve ▾`: **"Done/Approve with a note…"** and
     **"Request changes…"** (write overall feedback with zero annotations — the note lands as a
     general comment and submits as an ordinary change-request; this is where the in-flight
     pill's zero-state note path survives).
   - Feedback present, `Send Feedback · n ▾`:
     - **"Send with a note…"** — overall note on top of the annotations (user request 1's fast path);
     - review: **"Approve with notes"** (capability-gated — see delivery dependency; annotations
       ride along as non-blocking guidance; no confirm, nothing is lost) and
       **"Approve, discard n annotations…"** (always present, one honest confirm);
     - annotate (no gate): **"Done, discard n annotations…"** (confirm) — a positive finish that
       sends the "reviewed, no feedback" record, an outcome that today does not exist (Close is a
       dismissal, not a "reviewed" record).
   **The composer lives inside the same popover**: choosing a "…with a note" item morphs the menu
   into the note field (branch composer, extracted to `packages/ui` per its own tripwire). Two
   steps, one anchored surface, no second popover. Esc steps back and keeps the draft; an empty
   note refocuses; every action button is explicitly labeled for its whole outcome ("Done — send
   note", "Send feedback with note", "Request changes").
3. **Close demotes to a quiet ghost X** at the cluster's left. It warns only when content would be
   lost (the existing dialog). Tooltip carries the flavor-specific consequence: annotate-last
   "Dismiss without telling the agent", file/folder "Close session without sending", review
   "Close review without feedback". Compact keeps it as a menu row.
4. **`Mod+Enter` = the visible primary.** Outside the popover it triggers the left segment (which
   legalizes the existing hidden annotate behavior: at zero, `Mod+Enter` = Done = the same
   "reviewed, no feedback" payload it silently sends today). Inside the composer it triggers the
   composer's labeled action. One primary per state means keyboard and header can never disagree.

### Resulting states

| State | Annotate (file/folder/last) | Review (agent) |
|---|---|---|
| Empty | `[x] [Done v]` — menu: with a note / request changes | `[x] [Approve v]` — menu: with a note / request changes |
| Feedback present | `[x] [Send Feedback · n v]` — menu: with a note / done-discard (confirm) | `[x] [Send Feedback · n v]` — menu: with a note / approve with notes (gated) / approve-discard (confirm) |
| Gate (annotate) | maps to the review row — gate ≈ review | — |

One decision button in every state. Every named user request stays one gesture (or one gesture +
one menu pick):

- *"That's fine & submit"* (feedback 2, annotate-last): click **Done**. With a word of praise:
  caret → "Done with a note…".
- *"Overall annotation in review"* (feedback 1): caret → "Send with a note…" (fast path), **plus**
  a durable **+ General comment** button in the review sidebar's General section — parity with
  annotate's floating "Global comment" (`Viewer.tsx:872`). A general comment counts as feedback,
  so creating one flips the control to Send Feedback.
- *"Send feedback along with an approval"* (feedback 3): review caret → **"Approve with notes"**,
  rendered only when the capability advert says the runtime delivers feedback on approve. This
  generalizes the annotate gate's existing `getAnnotateApprovalPolicy` rather than inventing a
  second mechanism.

### What this deletes

- The header-level Approve button in every feedback-present state — and with it the dimmed
  treatment, the hover tooltip, and the "Annotations Won't Be Sent" approve dialog (replaced by
  one confirm on the explicit discard menu item; the Close-with-feedback warning stays for the
  ghost X).
- "No Annotations" and "Add Feedback First" dead ends (unreachable once no send action is offered
  at zero).
- The in-flight pill's zero-state meaning flip (the caret menu replaces it; composer and note
  transport are kept verbatim).

### Delivery dependency (must respect)

- Plan-approve hook path: the approval channel **cannot** carry side-band feedback — plan mode is
  deliberately out of scope; nothing here changes plan-approve.
- Annotate approve: `/api/approve` already accepts feedback + annotations
  (`buildAnnotateApprovalBody`); capability is already modeled (`approvalNotesSupported`).
- Review approve: the server accepts feedback text with `approved: true`, but four runtime
  consumers currently discard it. Therefore **"Approve with notes" ships dark** behind a
  per-session capability flag (advertised like `approvalNotesSupported`); until a runtime
  delivers, the review menu offers only "Send with a note…" and "Approve, discard n
  annotations…". Never render an item that silently drops content.

### Translation checks (model-level only)

- **Compact/touch:** the caret menu items become ActionMenu rows with the same state-driven
  visibility (`compactSessionActions`, `compactReviewActions`); the composer is the review
  branch's dialog, unchanged.
- **HTML/live-app surfaces:** the eye/refresh/pen cluster is untouched; only the action cluster to
  its left changes.
- **Keyboard:** one binding (`Mod+Enter`) covers both outcomes by state; the caret gets
  `aria-expanded` + a named `aria-label` and the menu is a proper `role="menu"` with arrow-key
  navigation (the ActionMenu primitive already exists).
- **WebMCP/external annotations:** external annotations already count into `hasAnyAnnotations` /
  `totalAnnotationCount`, so agent-created comments flip the control exactly like human ones. No
  new tools; decisions stay human.

---

## 4. Alternatives considered (real trade-offs only)

- **Two-button layout (promoted Send + dimmed Approve beside it).** My first draft; rejected by
  the maintainer — "I don't like seeing the approval and send feedback next to each other ever."
  The single control with the alternate decision in the caret menu is strictly simpler and loses
  only one thing: approve-despite-notes goes from one click to two (caret + item). That path is
  rare and semi-destructive; two deliberate clicks is arguably correct for it.
- **Menu-first with the note field always inline at the top of the menu.** Saves the second step,
  but every caret-open then raises a textarea (heavier, focus-steals on touch, and makes the
  decision items visually subordinate to typing). The morph keeps the menu scannable; the field is
  one pick away. Rejected, noted as a cheap follow-up experiment if the two-step feels slow.
- **Single adaptive button that relabels with no caret.** Minimal chrome, but approve-with-note,
  request-changes-at-zero, and approve-despite-notes all become unreachable, and the dead-end
  dialogs come back. Rejected.
- **Keep the in-flight pill as designed.** Ships sooner; re-introduces a Send button at zero and
  flips the left segment's meaning — both contradict the maintainer's stated confusion. Absorb
  (composer, transport, compact dialog), don't ship as-is.
- **Keep Close as a labeled pill.** More discoverable, but it is the rarest action; the ghost X
  plus menu row keeps it reachable while ending the gray-pill row. If people miss it, promote it
  back on the empty state only.

---

## 5. Migration path

Each step lands independently; no step regresses current behavior.

1. **Extract the composer** (`SubmitNoteField` in `packages/ui`) from the branch components, per
   their tripwire comment. Pure refactor of in-flight code.
2. **Build the shared decision control** (`packages/ui`): split pill + caret menu + in-place
   composer morph, driven by a small declarative spec (`{ primary, menuItems[] }`) so both apps
   and both states are data, not forks. Reuse the ActionMenu primitive for the menu.
3. **Annotate: adopt the control.** Empty → Done ▾ (submits the existing empty-feedback payload;
   menu: note / request-changes); feedback → Send Feedback · n ▾ (menu: note / done-discard with
   confirm). Close becomes ghost-X. `Mod+Enter` mapping already correct. Update
   `compactSessionActions` rows.
4. **Review: adopt the control.** Same two states; remove `AgentReviewActions`' three-button row,
   the dimmed treatment, tooltip, and the approve warning dialog (replaced by the discard-confirm).
   Wire the note to a general CodeAnnotation + send, request-changes-at-zero to the same path.
5. **Review sidebar: + General comment** in the General section header (creates an editable
   `scope:'general'` annotation authored by the identity, like annotate's global comment).
6. **Approve-with-notes (review), behind capability.** Server advert + per-runtime delivery work;
   enable the menu item per-origin as consumers stop discarding feedback on approve.
7. **Cleanup.** Delete dead-end dialogs ("No Annotations", "Add Feedback First"), the stale
   `AgentReviewActions` comment, and the branch pills' zero-state branch; update
   `tests/UI-TESTING.md` flows and the shortcut docs (labels only — no binding changes).

Tests worth writing (per the repo's testing rules — each guards a regressable behavior): the
state→(primary, menu items) matrix for both apps, including "Approve and Send Feedback never
render together"; the left segment never opens the popover; Done submits the exact legacy
empty-feedback payload; "Approve with notes" absent when the capability is absent; discard items
always confirm; a general comment flips the control; request-changes-at-zero submits
`approved: false` with the note as a general comment.
