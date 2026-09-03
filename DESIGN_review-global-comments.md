# DESIGN — General (review-level) comments in Code Review

Status: proposal. Untracked by convention — do not `git add`.
Surface: `packages/review-editor` (code review). Not plan review, not annotate.

---

## 1. Problem statement

A user asked whether comments about **the change as a whole** — not anchored to a file or a
line — are possible in code review, and suggested a dropdown on **Send Feedback**:
"submit with a global comment".

The interesting finding is that the *model* already supports this completely. What is
missing is a way for a human to create one.

### What already exists

`CodeAnnotationScope` has had a third member since Call Flow shipped:

```ts
// packages/ui/types.ts:155-158
// 'general' is a review-level comment tied to no file and no line. For 'general'
// (and the file-less case) filePath is "" and lineStart/lineEnd are 0 — consumers
// must branch on scope, never read those sentinels as a real path or row.
export type CodeAnnotationScope = 'line' | 'file' | 'general';
```

Today the **only** producer of `scope: 'general'` is
`resolveCallFlowAnnotationPlacement` (`packages/review-editor/utils/callFlowAnnotations.ts:78`),
for a Call Flow selection whose steps are entirely structural and map to no patch line.
Everything downstream of it is already built:

- exported to the agent under a `## General` section (`utils/exportFeedback.ts:324-345`),
- rendered in the sidebar under a pinned **General** group with a `general` chip
  (`components/ReviewSidebar.tsx:197-237`, `:470-478`),
- posted into the PR/MR review body (`components/ReviewSubmissionDialog.tsx:119`),
- accepted from external tools over `POST /api/external-annotations`
  (`packages/core/external-annotation.ts:269-290`),
- counted, drafted, and undoable like any other annotation.

So this is not a new feature. It is **an existing annotation scope with no human
affordance**, plus a couple of small gaps that only show up once a human can make one.

### How is this different from the feedback box? (the crisp answer)

There are two things that look like "the feedback box", and neither is a general comment.

**Agent mode (the default Plannotator flow): there is no feedback box at all.**
`handleSendFeedback` (`App.tsx:3489-3521`) POSTs `feedbackMarkdown` to `/api/feedback`, and
`feedbackMarkdown` is built *purely from annotations* (`App.tsx:3447-3465`). There is no
textarea anywhere in the send path. A reviewer in agent mode literally cannot say anything
that is not anchored to a file, a line, a PR comment, or a Call Flow step. **That is the
gap the user hit.**

**PR/platform mode: `platformGeneralComment` is a platform-body staging field, not a comment.**
It is App-level state (`App.tsx:689`) rendered inside `ReviewSubmissionDialog`, seeded from
prose notes at dialog-open (`App.tsx:3690`), and consumed by `buildPlatformReviewBody`. It
differs from a general comment on every axis that matters:

| | `platformGeneralComment` | a general annotation |
|---|---|---|
| Reachable | only after clicking Post comments | any time during the review |
| Exists in agent mode | no (PR mode only) | yes |
| Reaches the local agent | **no** — the platform path POSTs a bare status line with `annotations: []` (`App.tsx:3643-3651`) | yes, in `## General` |
| Count | exactly one | many |
| Editable / deletable afterwards | no | yes |
| Survives a crash | no (not in the draft) | yes (`useCodeAnnotationDraft`) |
| Undo/redo | no | yes |
| Counts toward the badge / enables Send Feedback | no | yes |
| Attributed (`author`, `createdAt`) | no | yes |
| Reachable by external tools / a future WebMCP catalog | no | yes |

So: **no, this is not "the feedback box, but earlier"**. In the flow the user is actually in
(agent mode), the feedback box does not exist; and where it does exist, it is a write-only
platform field on a terminal dialog. What is wanted is a first-class comment whose anchor
happens to be "the whole change".

---

## 2. Recommendation

### Primary affordance — a persistent **General comment** button in the review header

One icon button in the header's sidebar-toggle cluster, immediately **left of the
Annotations toggle**, opening the *existing* `CommentPopover` anchored to itself. This is a
deliberate mirror of plan review, where the same idea is one button in the Viewer actions
cluster (`packages/ui/components/Viewer.tsx:871-891`, "Global comment") feeding
`AnnotationType.GLOBAL_COMMENT`.

```
header:  … [ 🗨+ ]  [ 🗨 4 ]  [ ✨ ]  [ ⚙ ]   │   [ Send Feedback ]  [ Approve ]
             │         └── existing Annotations sidebar toggle (badge counts it)
             └── NEW  "General comment"   (shortcut: N)
                  ↓ opens the existing CommentPopover, isGlobal, draftKey'd
             ┌────────────────────────────────────┐
             │ General comment                    │
             │ ┌────────────────────────────────┐ │
             │ │ Error handling in the new      │ │
             │ │ client is inconsistent with…   │ │
             │ └────────────────────────────────┘ │
             │  [📎]                ⌘↵ to comment │
             └────────────────────────────────────┘

sidebar (Annotations tab), unchanged except for [+]:
  ┌ Annotations  4 ────────────────┐
  │ General                    [+] │ ← secondary affordance
  │  ┌ general · tater · 2m ─────┐ │
  │  │ Error handling in the …   │ │
  │  └───────────────────────────┘ │
  │ client.ts                      │
  │  ┌ L42-48 · …                │ │
```

Why the header:

- **Discoverable mid-review, without opening anything.** The review sidebar defaults to
  closed (`useSidebar<ReviewSidebarTab>(false, 'annotations')`, `App.tsx:452`), so a
  sidebar-only affordance is invisible to most reviewers most of the time. The header
  cluster is on screen for the entire session.
- **It is where the counterpart already lives.** The Annotations toggle and its badge sit
  right there; putting the producer next to the consumer reads correctly.
- **It costs the monolith almost nothing.** `CommentPopover` is already imported and used
  by review-editor for file comments (`AllFilesCodeView.tsx:2652-2665`) with exactly the
  props needed (`isGlobal`, `draftKey`, `anchorEl`). No new composer.
- **Zero new concepts.** The reviewer sees the same comment box they get from a line
  selection or a file header.

### Secondary affordance — keyboard `N`, plus a `[+]` in the sidebar's General group

- **`N`** ("note"), registered in `reviewEditorShortcuts` under **File Actions**' sibling
  section **Actions**. It joins the existing unmodified-key family (`V` toggle viewed,
  `A` stage file, `C` comment on file in the all-files view), which is exactly the right
  neighbourhood: `C` comments on a file, `N` notes the review. Single-letter avoids the
  `Mod+Shift+N` / `Mod+Shift+C` browser collisions. Guarded by the same typing guard the
  other single-key review shortcuts use.
- **`[+]` on the sidebar's "General" group header**, and a line in the empty state. Cheap
  (one prop, one button), and it closes the loop for a reviewer who is already in the panel
  triaging comments.

Both are secondary: the header button is the one that has to work.

**Compact touch:** the header sidebar toggles are hidden below the compact-touch breakpoint
(`App.tsx:4378`). The compact route is an item in `ReviewHeaderMenu`, matching how
compact-touch review already relocates dense header controls into that menu.

### Naming

UI label **"General comment"** (button title "Add a general comment"). Not "global": the
sidebar group already says **General**, the export heading already says **## General**, and
the type is already `scope: 'general'`. Plan review's "Global comment" wording stays as it
is; the two surfaces have different vocabularies already (`Annotation` vs `CodeAnnotation`)
and consistency *within* code review is what the reviewer actually sees.

---

## 3. Data model decision

**Verdict: reuse `CodeAnnotation` with `scope: 'general'`. Add no field, add no state.**

An important correction to the framing: the thing to reuse is **not**
`AnnotationType.GLOBAL_COMMENT`. That enum member belongs to `Annotation` — plan review's
document type, keyed on `blockId` / `originalText` / `startOffset` — and code review's
collection is `CodeAnnotation`, a different shape entirely. Putting an `Annotation` into
the review annotation array would break every consumer. The external API says the same thing from the
other side: review mode's type allowlist is `["comment", "suggestion", "concern"]`
(`packages/core/external-annotation.ts:214`) and `GLOBAL_COMMENT` is plan-mode only
(`:118`), so a review POST carrying it is already a 400. The correct reuse is the scope that
already exists on `CodeAnnotation`, which the codebase already documents as "a review-level
comment tied to no file and no line".

(The two are conceptually the same idea per surface, and a future WebMCP review catalog
should map `add_comments`' "document-level note" to `scope: 'general'` the same way the
editor catalog maps it to `GLOBAL_COMMENT` at `packages/editor/webmcp/documentTools.ts:565`.)

### Subsystem-by-subsystem verification

| Subsystem | Handles a `scope:'general'` annotation today? | Evidence | Work needed |
|---|---|---|---|
| Type / sentinel contract | ✅ | `packages/ui/types.ts:155-158` — sentinels (`filePath:''`, lines `0`) are documented, consumers told to branch on scope | none |
| Creation plumbing | ✅ | `addCodeAnnotationsWithHistory(items: readonly CodeAnnotation[])` (`App.tsx:1942-1953`) is scope-agnostic; `withPRContext` stamps PR/commit/GitButler context uniformly | none |
| Agent export | ✅ | `exportReviewFeedback` splits `general` out of `placed` and renders `## General` via `renderGeneralComments` (`utils/exportFeedback.ts:324-345`, `:272-288`) | reorder only (§4) |
| Platform (PR/MR) export | ✅ | `buildFileScopedBody` emits general text with **no path prefix** (`ReviewSubmissionDialog.tsx:119-121`); `buildPlatformReviewBody` concatenates it after `platformGeneralComment` | none — and note this means general comments already reach GitHub/GitLab, with no double-posting risk |
| Sidebar panel | ✅ | `SCOPE_ORDER = { general: 0, file: 1, line: 2 }`, split + pinned "General" group (`ReviewSidebar.tsx:112, 197-237, 470-478`), `general` chip at `:246-260` | add `[+]`, add `onEdit` (§5) |
| Undo / redo (#1426) | ✅ | `useUndoHistory` + `applyCollectionMutations` operate on the collection by **id only** (`packages/ui/utils/undoHistory.ts:76-96`, `App.tsx:608-641`); add/edit/delete records are shape-agnostic (`App.tsx:1947`, `:2162`, `:2197`). No file/line assumption, no re-anchoring, no scroll-or-reveal on undo (unlike `handleNavigateToAnnotation`). Already exercised by a file-less annotation: Call Flow's review-scoped add goes through the same `addCodeAnnotationsWithHistory` | none — see the three notes below the table |
| Draft persistence | ✅ | `useCodeAnnotationDraft` stores `CodeAnnotation[]` verbatim (`packages/ui/hooks/useCodeAnnotationDraft.ts:14-31`) — no per-file filtering or validation | none |
| External annotations POST | ✅ | `VALID_SCOPES` includes `"general"` (`packages/core/external-annotation.ts:216`); `if (scope !== "general")` skips the `filePath` requirement entirely (`:269-303`); `classifyFindingPlacement` already returns the general sentinel at `:235-254`. The only requirements are `source` plus one of `text`/`suggestedCode`. Pi's vendored copy is byte-identical apart from one import extension — no validation drift | none |
| External PATCH / DELETE | ✅ | `handleEditAnnotation` / `handleDeleteAnnotation` route by `source` + id, never by location (`App.tsx:2134-2205`). Server-side PATCH is a shallow merge that pins only `id` and `source` (`packages/core/external-annotation.ts:460-464`) — it does **not** re-run the location validator, so a PATCH can set `scope` to an arbitrary string or flip `line`↔`general` unchecked. Pre-existing and not widened by this feature, but do not write code that assumes `scope` is always one of three | none |
| Badge + submit enablement | ✅ | `totalAnnotationCount = allAnnotations.length + …` (`App.tsx:3467`); `handleSendFeedback` gates on `totalAnnotationCount === 0` (`App.tsx:3490`). A general-only review therefore enables Send Feedback and dims Approve with the correct count | none |
| General-only export | ✅ | `exportReviewFeedback` early-returns only on `annotations.length === 0`; with only general items `renderScopedGroups([])` yields `''` and the header + `## General` still render | none |
| Auto-viewed (#1430) | ✅ n/a | `utils/autoViewed.ts` is a pure dwell/geometry machine over **file paths**; annotations are not an input and never mark or suppress a file | none — no interaction by construction |
| Guided review / guides.show viewer | ✅ n/a | the guide chain is `readOnly`; it renders no composer and creates no annotations | none |
| PR-scope filtering | ✅ | `annotationMatchesPrScope` keys on `prUrl` + `diffScope` only (`utils/annotationScope.ts:11-19`); a general comment stamped by `withPRContext` hides/reveals across an in-place PR switch exactly like a file comment | none |
| Copy text | ✅ | `copyLocationPrefix` returns `''` for general (`utils/annotationDisplay.ts:18`) | none |
| Dock panels (diff / all-files / call flow) | ✅ | line-annotation projection is gated on scope; general never enters `lineAnnotationMetadata` or a Pierre slot | none |
| **Navigate-to-annotation** | ⚠️ **silently no-ops** | `handleNavigateToAnnotation` (`App.tsx:3195-3199`) routes non-line annotations **that carry `callFlowTargets`** to the Call Flow panel. A general comment *without* them (i.e. exactly what this feature creates) falls through to `files.findIndex(f => f.path === '')` → `-1` (no switch), then issues `setScrollTargetAnnotation` for a target that dead-ends at `AllFilesCodeView.tsx:2191-2193`. Nothing throws — the click just does nothing visible. The condition wants to be a **scope** check, with the Call Flow panel opened only when `callFlowTargets` exist | 3-line guard (§5) |
| Sidebar editing | ⚠️ **missing** | `renderAnnotationCard` passes `CommentActions` only `copyText` + `onDelete` (`ReviewSidebar.tsx:293-296`). File comments get inline editing via `FileCommentCard`; general comments have nowhere to be edited from, because they have no diff surface | add `onEdit` (§5) |
| `allAnnotations` external dedup | ⚠️ pre-existing edge | the dedup key is `(source, type, filePath, lineStart, lineEnd, side)` (`App.tsx:891-899`) — all sentinels for general, so two general findings from the same external source are indistinguishable and a draft-restored copy can be dropped against the wrong one. Pre-existing, unreachable from the human path (local comments have no `source`) | note only; optional id-based fix |
| `inReplyTo` / threading | n/a | `inReplyTo` lives on `Annotation`, not `CodeAnnotation`; code review has no comment threading on any scope | out of scope (§8) |

### Three notes on the undo/redo integration (behavior to know, not work)

1. **The undo entry does not outlive a diff refresh.** The history context is
   `snapshotId ?? prMetadata?.url ?? diffData?.gitRef` and the stack is cleared on any
   `diffData.rawPatch` change (`App.tsx:607`, `:642-644`). A review-level comment is
   conceptually *not* bound to a patch and the annotation itself survives a refresh — but
   its undo entry does not. This is the existing mechanism applied to a new shape, not a
   regression; flag it only so nobody promises otherwise.
2. **`Mod+Z` correctly stays with the composer while it is open.**
   `canHandleReviewHistoryShortcut` (`App.tsx:3744-3749`) bails on `isNativeHistoryOwner`
   and on `hasActiveHistoryOverlay(document)`, which matches `[data-comment-popover="true"]`
   among others. Reusing `CommentPopover` gets this for free — a bespoke composer would have
   to carry one of those markers itself. This is a further argument for not inventing a new
   composer.
3. **Externals and restore clear the stack.** `isHumanHistoryMutation` is `!item.source`
   (`undoHistory.ts:145`), so editing or deleting an externally-POSTed general comment
   clears the whole stack (`App.tsx:2143`, `:2178`), and `handleRestoreDraft` clears it too
   (`App.tsx:919-927`) — a draft restore is not undoable. Capacity is 50, shared across all
   three annotation stores.

**Net: three small fixes, all in review-editor. No schema change, no server change, no
migration, no draft-format change, no @plannotator/ui change on the primary path.**

---

## 4. Export format

Keep the existing `## General` section and its `renderGeneralComments` body (conventional
prefix, reasoning, Call Flow targets). **One change: move the section above the file groups.**

```markdown
# Code Review Feedback

**Diff:** All changes since `origin/main` (committed + uncommitted + untracked)

## General

**issue (blocking):** Error handling in the new client is inconsistent with the rest of the repo.

Consider splitting this PR — the rename is unrelated to the fix.

## src/client.ts

### Lines 42-48 (new)
**suggestion:** …
```

Rationale for moving it (`exportFeedback.ts:344-345`, one line):

- **Plan review's precedent is globals-first.** `GLOBAL_COMMENT` carries `blockId: ''`, so
  `blocks.findIndex(...)` returns `-1` and it sorts ahead of every anchored annotation
  (`packages/ui/utils/parser.ts:1151-1156`). The two surfaces should read the same way.
- **It matches GitHub/GitLab**, where the review body precedes the inline comments — and
  matches `buildPlatformReviewBody`, which already puts general text at the top of the body.
- General comments are usually **framing** ("this PR does two things", "the whole approach
  needs a rethink"). An agent that reads them after twenty inline nits has already started
  planning the wrong work.

Cost: one line moved plus one ordering assertion. Today's only general producer is Call
Flow, whose existing tests assert `toContain('## General')` and are order-agnostic
(`utils/exportFeedback.test.ts:83-98`).

**Multiple general comments** render as consecutive paragraphs under the one heading — that
is what `renderGeneralComments` already does. **Multi-PR export**: general comments stay
out of the per-PR grouping and render once at the end (`exportFeedback.ts:376`). That is
correct — a review-level note belongs to the review, not to one of its PRs — and it stays
correct after the reorder (the multi-PR branch keeps `generalSection` at the end because
each PR block has its own heading; only the single-PR/local branch moves).

---

## 5. Implementation sketch

Monolith footprint deliberately minimized, per the auto-viewed precedent (decision core in
its own module, App holds only the wiring).

**New — `packages/review-editor/components/GeneralCommentButton.tsx` (~70 lines)**
Owns its own open state and its `anchorEl` ref; renders the header button and, when open,
the existing `CommentPopover` with `isGlobal`, `allowImages`, and
`draftKey={`general:${prUrl ?? ''}:${prDiffScope ?? ''}`}` (same keying discipline as the
file-comment popover, so a PR switch does not resurrect a stale draft). Props:
`{ onSubmit(text, images?), disabled? }`. Exposes an imperative `open()` for the shortcut.
Nothing about it is App-shaped, so it is also the compact-touch menu's action target.

**`packages/review-editor/App.tsx` (~35 lines net)**
```ts
const handleAddGeneralComment = useCallback((text: string, images?: ImageAttachment[]) => {
  const trimmed = text.trim();
  if (!trimmed) return;
  addCodeAnnotationsWithHistory([withPRContext({
    id: generateId(), type: 'comment', scope: 'general',
    filePath: '', lineStart: 0, lineEnd: 0, side: 'new',
    text: trimmed, ...(images?.length && { images }),
    createdAt: Date.now(), author: identity,
  })]);
}, [identity, withPRContext, addCodeAnnotationsWithHistory]);
```
Modelled line-for-line on `handleAddFileComment` (`App.tsx:2092-2111`). Plus: one
`<GeneralCommentButton>` in the header cluster, the `N` handler in the existing shortcut
wiring, and the navigate guard:
```ts
// review-level notes have no diff destination — select, don't fake a scroll
if ((annotation.scope ?? 'line') === 'general') { setSelectedAnnotationId(id); return; }
```
placed just above the existing Call-Flow branch at `App.tsx:3195`, which then becomes
redundant for `general` and stays for `file`-scoped Call Flow comments.

**`packages/review-editor/shortcuts.ts` (~8 lines)** — `addGeneralComment: { description:
'Add a general comment', bindings: ['N'], section: 'Actions' }`. Marketing's shortcut docs
page picks it up at next build with no further work.

**`packages/review-editor/components/ReviewSidebar.tsx` (~30 lines)** — optional
`onAddGeneralComment` and `onEditAnnotation` props; `[+]` on the General group header; a
"Add a general comment" line in the empty state; and pass `onEdit` through to
`renderAnnotationCard` for general-scoped cards (reusing `FileCommentCard`'s inline-editor
pattern, or lifting that editor into a shared card once the second caller exists).

**`packages/review-editor/utils/exportFeedback.ts` (1 line moved)** — `generalSection`
emitted before `renderScopedGroups` in the single-PR/local branch.

**`packages/review-editor/components/ReviewHeaderMenu.tsx` (~12 lines)** — compact-touch
menu item.

**Published-package rules:** no change to `@plannotator/ui` is required for increments 1-3.
`CommentPopover`'s `isGlobal` / `draftKey` / `allowImages` props already exist and are
already used from review-editor. If increment 4 wants an inline editor on the sidebar card,
the only `ui` touch is an **optional** `onEdit` on `CommentActions` — purely additive,
default-absent, existing callers byte-identical.

**Effort: ~1 day** for increments 1-3 (~200 lines net, of which ~35 land in `App.tsx`), plus
~half a day for 4-5.

---

## 6. Test plan

Per CLAUDE.md Testing Rules — each test below names a regression it catches. Nothing here
snapshots prose.

**`utils/exportFeedback.test.ts`** (extend)
1. *"general comments render before file groups"* — asserts `indexOf('## General') <
   indexOf('## src/client.ts')`. Catches: a future refactor of `exportReviewFeedback`
   silently restoring the old order, which would bury framing feedback under nits.
2. *"a general-only review still emits a header and the general section"* — catches the
   real risk that a `placed.length === 0` shortcut gets added and a review whose only
   content is general comments exports as "No feedback provided."
3. *"multi-PR export emits general comments exactly once, outside the PR blocks"* — catches
   a general comment being duplicated into each PR group by the `byPR` loop.

**`components/ReviewSubmissionDialog.test.ts`** (extend)
4. *"a general comment reaches the platform body without a file prefix, and is not posted
   as an inline comment"* — asserts it appears in `fileScopedBody` and that
   `buildAnnotationFileComments` returns nothing for it. Catches a `scope` filter regression
   that would try to POST an inline comment at `path: '', line: 0` (GitHub 422).

**New `App.generalComment.test.tsx`** (component-level, following the existing
`AllFilesCodeView.*.test.tsx` / `useAutoViewed.test.tsx` style)
5. *"submitting the header composer appends one general-scoped annotation and Mod+Z removes
   it"* — the one test that proves the undo integration end to end, because the history
   record is built at the call site and a hand-rolled `setAnnotations` would silently skip it.
6. *"clicking a general comment in the sidebar selects it and issues no scroll target"* —
   catches the dead-click gap in the table, and catches a future navigate refactor
   reintroducing it.

**`utils/annotationScope` / external** — no new tests: `scope: 'general'` acceptance is
already exercised by the external-annotation validator suite, and this change adds no
producer there.

**Deliberately not tested:** that the button renders with a given label (round-trip prop
test), the popover's own behavior (owned by `CommentPopover`'s existing suite), draft
round-tripping (the transport is opaque to scope, and asserting it would restate the code).

**Manual (`tests/UI-TESTING.md`, one line):** open a review with no diff selection, press
`N`, type, `Mod+Enter`, confirm the badge increments, the sidebar's General group shows it,
Send Feedback carries it, and a reload restores it from the draft.

---

## 7. Severable increments

1. **Create + export.** Header button, `handleAddGeneralComment`, navigate guard. Shippable
   alone: everything downstream already works. *This is the whole ask.*
2. **Shortcut `N`.** Independent; marketing docs regenerate for free.
3. **Export reorder.** Independent of 1 and 2 (it improves today's Call Flow output too).
4. **Sidebar `[+]`, empty-state hint, and inline edit for general cards.** Independent;
   the only increment that touches `@plannotator/ui` (additive optional prop).
5. **Compact-touch menu item.** Independent.

Shipping 1 alone is a coherent release. 4 is the one most likely to be deferred.

---

## 8. Rejected alternatives

**A. Dropdown on Send Feedback ("submit with a global comment") — the user's suggestion. Rejected.**
It solves the wrong half of the problem. The user's own framing is "jot global thoughts *as*
I review"; a submit-time dropdown is reachable only at the moment the review ends. Beyond
that: it adds a step to the single most-used control in the app; it puts a *composer* behind
a menu on a terminal action, where an accidental dismiss loses the text; it can only ever
produce one comment, which cannot be edited, deleted, re-read, or undone; and in PR mode it
would sit next to `platformGeneralComment` — a second, differently-scoped general box on the
same dialog, which is exactly the confusion to avoid. The value it *does* have (visibility at
submit time) is already covered: the submission dialog renders general comments in its body
preview, and Approve dims with "Your N annotations won't be sent."

**B. Promote `platformGeneralComment` to an always-visible first-class comment list. Rejected.**
It is not a comment — it is the staging buffer for the GitHub/GitLab review body, seeded
from prose notes and consumed by `buildPlatformReviewBody`. It exists only in PR mode, never
reaches the local agent, and is already *fed* by general annotations through
`buildFileScopedBody`. Promoting it would either duplicate content into the platform body
(a general annotation arriving twice) or require rewriting the platform submission path for
no reviewer-visible gain. Leave it as the platform body field it is; general annotations
flow into it correctly today.

**C. A dedicated `generalComments: string[]` field / separate collection. Rejected.**
Every subsystem in §3's table would need a second code path: draft schema, undo history
action kind, badge arithmetic, submit enablement, export, platform body, external API,
sidebar. `scope: 'general'` gets all of it for free and is already the documented model.

**D. Reuse `AnnotationType.GLOBAL_COMMENT`. Rejected — wrong type.** That member belongs to
plan review's `Annotation`; the review collection is `CodeAnnotation`. See §3.

**E. A sidebar-only affordance (no header button). Rejected as primary, adopted as secondary.**
The sidebar defaults closed, so the feature would be invisible to a reviewer who has not
already opened it — failing the "discoverable mid-review" bar. Good as a second door.

**F. Repurpose the "Ask AI general" entry point. Rejected.** `onAskGeneral` opens an AI
question, not a comment. Overloading it would make the two indistinguishable.

---

## 9. Open questions

Only two, and only one changes the work:

1. **Does the export reorder (§4) need maintainer sign-off?** It changes the agent-facing
   output for existing Call Flow general comments. Benign and covered by one test, but it is
   the only behavior change to already-shipping output in this proposal. If the answer is
   no, drop increment 3 and the design is otherwise unchanged.

2. **Should `CodeAnnotation` gain `inReplyTo` so general comments can thread?**
   Recommendation: **no, not here.** Code review has no threading on any scope; adding it
   for one scope would fork the model and pull in the panel/export/validation work
   `Annotation.inReplyTo` needed on the plan surface. Noted so a future WebMCP phase-2
   catalog does not assume it exists.

Not open, for the record: multiple vs one general comment (multiple — it is a collection);
whether they count toward the badge and enable Send Feedback (yes, automatically); whether
they interact with auto-viewed (they cannot).
