# DESIGN: Auto-mark files viewed on scroll (code review)

Status: design only, not implemented. Repo-root DESIGN_*.md files stay untracked by convention.

## Problem and goals

Reviewers reading the all-files diff top-to-bottom must still check every file off by hand (`v` or the header Viewed button). The request: as the reviewer scrolls past files, or moves on from an opened file, mark them viewed automatically. Must be a setting, ON by default (maintainer decision), with an easily reachable off switch and a one-time "this is on, here's the off switch" notice for new and existing users.

Non-goals: changing what "viewed" means for submission (it gates nothing today and continues to gate nothing), server-side persistence beyond the existing draft, and any change to Guided Review section progress.

## Grounding: how viewed works today (verified in code)

- **State**: `viewedFiles: Set<string>` keyed by repo path, App-local (`packages/review-editor/App.tsx:453`). Toggled by `handleToggleViewed` (`App.tsx:2095`), the `v` shortcut (`App.tsx:2212`, gated on `!guideOpen` and `isDiffPanelActive`), the FileHeader button, and staging (`onFileViewed` from `useGitAdd`, add-only).
- **Persistence**: rides the code-review draft (`viewedFiles?: string[]` in `DraftData`, `packages/ui/hooks/useCodeAnnotationDraft.ts`). Deliberately does NOT count toward `hasHadAnnotationsRef` engagement (GitHub-seeded viewed arrives without user action), but does count toward `isEmpty`.
- **Diff lifecycle**: `viewedFiles` is NOT reset on diff-type/base switches or staleness refreshes — only a PR switch replaces it from GitHub's state (`applyPRResponse`, `App.tsx:2253`). Viewed state therefore already survives refresh and base switches, path-keyed, even when a file's content changed. Marking viewed does not collapse the file card (the viewed delta only refreshes headers, `AllFilesCodeView.tsx:1745-1800`) — so auto-marking mid-scroll causes zero layout shift. `hideViewedFiles` filters the left panel only, not the all-files surface, so auto-viewing cannot yank content out from under the viewport.
- **GitHub sync**: PR sessions POST `/api/pr-viewed` per toggle; the endpoint already accepts a `filePaths` array (exists in both `packages/server/review.ts` and `apps/pi-extension/server/serverReview.ts`).
- **Chrome**: `reviewShowViewedControls` (registry, cookie-only) hides the buttons; the PanelChrome gear popover ("Tree controls") is the existing home for viewed-related chrome toggles; `PanelControlsRow` shows the `viewed/total` counter.

## Grounding: the scroll primitive (verified in code)

The all-files surface does NOT use IntersectionObserver. `AllFilesCodeView.tsx` tracks the file being read via `reportVisibleFile` (`~:1955`): on each scroll (rAF-coalesced) it walks CodeView's `getRenderedItems()` / `getTopForItem()` / `getScrollTop()` / `getHeight()` / `getScrollHeight()` and reports the last item whose top is ≤ scrollTop+50, with an at-bottom override for the final file. The file itself documents the decision to "ride CodeView's existing virtualization rather than layering our own observer" (`~:1443`). `GuideViewportManager` (packages/guide-viewer) is the guide chain's IntersectionObserver for section shells — wrong surface, wrong granularity; not reused here.

**Consequence**: "scrolled past" is computed from the same accessors on the same rAF tick — no new observers, no new geometry system.

## Semantics specification

One invariant unifies both surfaces: **a file becomes auto-viewed when the reviewer moves on from it after its content was actually on screen long enough to have been read.** "Arriving at" a file never marks it; "leaving it downward / moving on" does.

### Rule 1 — All-files surface: pass-below + dwell

A file P auto-views when all of the following hold at the moment the tracked reading file transitions away from P:

1. **Downward pass**: the transition is to a file later in `visualOrder`, AND P's bottom edge (top of its successor item, via `getTopForItem`) is at or above the viewport top (+small epsilon) — i.e. P has genuinely scrolled out above, not merely lost the "active" race. *Rationale: upward scrolls are returns, not completions; the geometric check stops a mid-file jump-away from counting as a full read-through when it isn't one, using accessors that already exist.*
2. **Dwell**: P has accumulated ≥ 1000 ms as the reported reading file this session (cumulative across visits, per diff snapshot). *Rationale: momentum-flicking to the bottom makes every intermediate file briefly active (rAF-coalesced); a dwell floor is the difference between "scrolled through" and "scrolled over". Cumulative, so bouncing between two files still accrues. 1000 ms is a named constant (`AUTO_VIEW_DWELL_MS`), tuned later if needed.*
3. **Expanded**: P's CodeView item has `collapsed !== true` for the dwell being counted. *Decision: scrolling past a collapsed card does NOT count — its content was never shown. Generated files (#1317) seed collapsed and are therefore naturally excluded until deliberately expanded, which is exactly right: nobody reviewed a lockfile by scrolling past its folded header.*

**Bottom of container**: when CodeView reports at-bottom (the existing ≤2 px check), the currently active last file is treated as "passed" once its dwell is met. *Rationale: the last file can never scroll out above; reaching the end of the diff is the completion signal.*

### Rule 2 — Single-file panel: navigate-away + dwell

Opening a file in the tree does **not** mark it viewed. When the single-file diff panel (`REVIEW_DIFF_PANEL_ID`) switches from file A to another file, or the panel closes/loses its file, A auto-views if it was the panel's file for ≥ the same dwell. *Decision: "opening counts" (the literal request) over-marks — a misclick or a 2-second glance would check the file off. Navigate-away-after-dwell is the Gerrit model and is the same invariant as Rule 1: mark on moving on, not on arrival. Keyboard file navigation drives the same panel switches, so keyboard-only parity is automatic; on the all-files surface, keyboard scrolling (space/PageDown/vim-style) produces the same scroll events as the wheel.*

### Rule 3 — Manual un-view suppresses auto-view (per file)

Un-viewing a file (any surface: `v`, header button, tree row) adds it to an `autoViewSuppressed` set; auto-view never marks a suppressed file again. Manually marking it viewed clears the suppression. *Rationale (mandated, and correct): un-viewing is the reviewer's "come back to this" gesture; an auto system that immediately re-checks it is hostile.* The suppression set persists in the draft (additive optional `autoViewSuppressed?: string[]` on `DraftData` — old drafts without it restore fine, new drafts are ignored gracefully by old builds). Deliberate edge: a draft that is otherwise empty (no annotations, no viewed files) is still `isEmpty` and gets deleted — suppression alone does not keep a draft alive; the worst case is a re-auto-view after reload in a session that looked abandoned. Accepting this keeps the existing `#948` clear-everything semantics untouched.

### Rule 4 — Scope: only the review target, never detours

Auto-view is inert while:
- `guideOpen` (the guide takeover CSS-hides the dock — same reasoning as the existing `v`/`a` shortcut gate at `App.tsx:2195`);
- a commit detour is active (`activeDiffBase` is `commit:<sha>`): the Commits view is documented as a session-only, self-contained detour — reading a historical commit's rendition of a file is not reviewing the change under review. Dwell timers pause; nothing marks.

It DOES run in PR mode (both layer and full-stack scope — both are the review target) and in workspace/GitButler/jj modes: viewed is plain client state everywhere. In PR sessions, auto-view marks route through the existing GitHub sync, **batched**: paths marked within a short window (~2 s) go out as one `/api/pr-viewed` POST (`filePaths` is already an array) instead of one request per file.

### Rule 5 — Diff refresh: changed files un-view (gated on this setting)

When a refresh/switch applies a new patch for the same session and a viewed file's per-path patch text changed, that file is removed from `viewedFiles` (GitHub's behavior). *Decision: yes, but ONLY while auto-viewed is enabled.* Rationale: with auto-marking, checkmarks accrue without explicit intent, so a stale check on content the agent just rewrote is actively misleading; but with the setting off, today's manual semantics must stay byte-identical (a user who hand-checked 40 files and pulls a one-line change should not lose unrelated state — and today they don't). Content-change un-view does NOT add to `autoViewSuppressed` — new content is a fresh auto-view opportunity. Dwell bookkeeping resets with `fileSetKey` (the CodeView remount already defines the snapshot boundary). PR switches keep their existing GitHub-authoritative reset.

### Rule 6 — Independence from Guided Review

Guide section "reviewed" state (server-persisted per guide via `/api/guide/:jobId/reviewed`) stays fully independent. *Recommendation: do not link.* Different granularity (sections span files; a section's files may include context the guide references), different lifecycle (guides persist across sessions; viewed is draft state), and the guide chain is shared with the read-only guides.show viewer where viewed does not exist. A future one-way nicety (guide section completed → mark its files viewed) can be added later without unwinding anything.

### Rule 7 — Submission

No change. The `viewed/total` counter in `PanelControlsRow` keeps rendering the same set; nothing gates submit on viewed count, and this feature does not introduce a gate.

## Setting design

- **Key**: `reviewAutoViewed`, boolean, **default `true`**. Cookie `plannotator-review-auto-viewed`. Registry entry in `packages/ui/config/settings.ts` beside `reviewShowViewedControls`, cookie-only (`serverKey: undefined`) — review-chrome preferences are deliberately cookie-only ("shape the local file-list chrome without changing review semantics", per the existing comment) and this is one.
- **Registry vs lazy (`preference.ts`-style)**: registry. The WebMCP lazy pattern exists to guarantee *zero footprint* on surfaces where the feature cannot exist (no `document.modelContext` → nothing written anywhere, provable A/B). Auto-viewed has no such requirement: it is an ordinary boolean review preference exactly like `reviewShowViewedControls`, which already seeds a `true` default cookie on every surface via `configStore.ensureLoaded`. One more seeded cookie is the established, accepted cost; inventing a second lazy store for a plain toggle would fragment the settings system for no invariant.
- **Settings dialog placement**: the **Git tab** (`GitTab` in `packages/ui/components/Settings.tsx`, review mode only), new "Viewed files" section under the diff-type picker:
  - Label: **"Auto-mark viewed"**
  - Description: *"Mark a file viewed when you scroll past it or move on to another file. Files you un-view stay un-viewed, and files that change on refresh become un-viewed."*
- **Easily-accessible secondary affordance**: a third switch row in the existing **PanelChrome "Tree controls" gear popover** (`data-review-tree-settings`), beside "Viewed controls" and "Git add controls": label "Auto-mark viewed", sub-label "Check files off as you scroll past". It writes the same `configStore` key (mirroring `handleToggleReviewViewedControls`). *Chosen over making the `viewed/total` counter chip clickable: the chip is a read-out — overloading its click with a behavior toggle is undiscoverable and misfire-prone, while the gear popover is already the canonical home of viewed-related chrome, two clicks from where the behavior manifests, visible in both Tree and Git-status panels.*

## First-time notice design

- **Vehicle**: a **sonner toast** (the app's existing pattern — cf. the update-available toast, `App.tsx:623-638`), NOT a dialog. The first-run dialog chain (guide intro → look-and-feel → review setup → Edit Mode) is explicitly closed to new members ("none of the dialogs stack"; analysis layers deliberately stopped adding startup dialogs), and a startup dialog would announce behavior the user hasn't experienced yet.
- **Trigger**: the **first time an auto-view actually fires** in this browser — the moment the feature is self-evidently demonstrating itself (a checkmark just appeared unbidden). Deferred (not lost) while `guideOpen` or any first-run dialog is visible: the marker still marks; the toast retries on the next fire. This also guarantees non-stacking by construction — it appears only after the reviewer is scrolling a diff, which post-dates the startup chain.
- **Copy** (draft):
  - Title: `Files are marked viewed as you scroll`
  - Description: `Scroll past a file or move on to the next and it's checked off. Turn this off in Settings → Git, or from the gear above the file list.`
  - Action button: `Turn off` → `configStore.set('reviewAutoViewed', false)`, followed by a confirmation toast: `Auto-mark viewed is off — re-enable it in Settings → Git.`
  - Duration ~10 s, dismissible, `position: 'top-right'` matching the update toast.
- **Dismissal persistence**: versioned seen-cookie `plannotator-auto-viewed-notice-seen = '1'` via a new `packages/review-editor/utils/autoViewedNotice.ts` mirroring `destinationSpotlight.ts` (cookie-based, survives random ports, version bumpable). Marked seen on: toast shown, `Turn off` clicked, or the setting explicitly toggled anywhere (Settings or gear popover) — an explicit toggle is proof of discovery; never show the toast to someone who already found the switch.

## Implementation sketch

No server changes in either runtime: viewed is client draft state (existing `/api/draft`), and PR sync reuses the existing batch-capable `/api/pr-viewed` in both `packages/server/review.ts` and `apps/pi-extension/server/serverReview.ts`. Pi and OpenCode receive the feature through the built HTML (same delivery as WebMCP phase 1). `@plannotator/ui` changes are additive: one registry entry (inert without the review surface) and one optional draft field (old drafts parse unchanged).

Files touched:

1. **`packages/review-editor/utils/autoViewed.ts`** (new, pure): the decision core — a small state machine holding per-path cumulative dwell, the suppression set, and `enabled`; inputs are `readingFileChanged(path | null, tsMs)`, `filePassed(path)`, `atBottom(path)`, `fileNavigatedAway(path)`, `suppress/unsuppress(path)`, `resetSnapshot()`; output is a `markViewed(paths: string[])` callback. Pure and clock-injected so it unit-tests without DOM.
2. **`packages/review-editor/components/AllFilesCodeView.tsx`**: extend `reportVisibleFile` (same rAF, same accessors) to additionally emit two optional callbacks: `onFileScrolledPast(path)` — fired on a downward active-file transition when the successor's top ≤ scrollTop+ε and the item was expanded — and reuse the existing at-bottom branch to emit for the final file. Collapsed check via `handle.getItem(id).collapsed`. Both props optional, defaulting to today's behavior (published-package rule).
3. **`packages/review-editor/hooks/useAutoViewed.ts`** (new): binds the pure core to App — reads `useConfigValue('reviewAutoViewed')`, gates on `guideOpen`/commit-detour, listens to `allFilesVisibleFile` changes and the single-file panel's `activeFileIndex`/`isDiffPanelActive` transitions for Rule 2, batches PR sync, and calls a new add-only `markFilesViewed(paths)` in App (shares the GitHub-sync body with `handleToggleViewed`).
4. **`packages/review-editor/App.tsx`**: wire the hook; `handleToggleViewed`'s un-view branch feeds `suppress(path)`, view branch `unsuppress(path)`; Rule 5 patch-delta un-view where refreshed files apply (`fetchDiffSwitch` apply path — compare prev/next per-path patch text with the existing `hashString`); first-fire toast.
5. **`packages/ui/hooks/useCodeAnnotationDraft.ts`**: optional `autoViewSuppressed?: string[]` on `DraftData`, threaded through save/restore. Does not participate in `isEmpty` or engagement (see Rule 3 edge).
6. **`packages/ui/config/settings.ts`**: `reviewAutoViewed` registry entry.
7. **`packages/ui/components/Settings.tsx`** (`GitTab`) + **`packages/review-editor/components/PanelChrome.tsx`** (gear popover row): the two toggles.
8. **`packages/review-editor/utils/autoViewedNotice.ts`** (new): versioned seen-marker.
9. Docs: `apps/marketing/src/content/docs/` review page mention; release notes at ship time.

### Test plan (each names the regression it guards)

- `autoViewed.test.ts` (pure core):
  - *Flick-through*: rapid downward transitions with <1000 ms dwell mark nothing — guards momentum scrolling marking the whole diff viewed.
  - *Read-through*: dwell + downward pass marks; upward transition never marks — guards direction inversion (scrolling up checking off files below).
  - *Cumulative dwell*: two 600 ms visits mark on the second pass — guards a refactor to "continuous dwell" silently raising the bar.
  - *Disabled*: `enabled=false` produces zero marks from identical input — guards the off switch not actually severing the pipeline.
  - *Suppression*: un-view → pass again → no mark; manual re-view → suppression cleared — guards the "come back to this" contract.
  - *Snapshot reset*: `resetSnapshot()` clears dwell but keeps suppression — guards dwell leaking across diff switches (instant false marks on the new diff).
- `AllFilesCodeView` (existing test style, mocked viewer handle): collapsed item transition emits no `onFileScrolledPast` — guards generated/collapsed cards auto-viewing from their folded headers.
- App-level (or hook test with mocked fetch): three marks inside the batch window produce ONE `/api/pr-viewed` POST containing all three paths — guards regression to request-per-file spam.
- Rule 5 test: refresh with one changed + one unchanged viewed file removes only the changed one, and removes neither when `reviewAutoViewed` is off — guards both the stale-checkmark bug and "default-off behavior stays byte-identical".
- Draft round-trip in `useCodeAnnotationDraft` tests: `autoViewSuppressed` saves/restores; a draft without the field restores with an empty set — guards old-draft compatibility.
- `autoViewedNotice.test.ts`: needs → mark → not-needed; explicit setting toggle marks seen — guards the toast re-showing every session (and showing after the user already found the switch).
- All tests sandbox storage per CLAUDE.md rules (no module-scope env/global mutation); no copy-snapshot assertions — the toast copy is checked only via the `Turn off` action's effect (`reviewAutoViewed` becomes false), which is the load-bearing behavior.

## Risks and rejected alternatives

- **Startup dialog** — rejected: the first-run chain is explicitly closed ("none of the dialogs stack"; analysis layers set the precedent of not adding startup dialogs), and announcing un-experienced behavior is worse than demonstrating it.
- **GitHub-style viewed-on-expand / manual-only** — rejected as the primary model: the all-files surface is a continuous reading pane, not GitHub's expand-per-file page; the request is precisely to remove the manual step. The sane half survives as the collapsed-card exclusion.
- **Mark on entering viewport** — rejected: over-marks everything below the fold of wherever the reviewer stops.
- **Reusing `GuideViewportManager` / per-file IntersectionObservers** — rejected: the all-files surface virtualizes through CodeView and `AllFilesCodeView` already documents the decision to ride CodeView's accessors rather than layer observers; an observer per virtualized item would fight recycling.
- **No dwell (pure pass geometry)** — rejected: rAF-coalesced momentum scroll makes every intermediate file transiently active; without dwell a single flick to the bottom marks the entire review viewed, which destroys trust in the checkmarks and the counter.
- **Un-view-on-change unconditionally** — rejected: changes manual-mode semantics users rely on today; gating it on the auto setting keeps the off state byte-identical.
- **Risk: dwell constant is wrong for very short files** (a 2-line file read at normal scroll speed may accrue <1000 ms). Accepted for v1; the constant is named and central. If reports come in, scale dwell by rendered item height before inventing per-file logic.
- **Risk: draft churn** — auto-marks trigger the existing 500 ms-debounced draft save while scrolling; same write path manual `v` uses today, debounce absorbs it.
- **Risk: default-ON surprises existing reviewers** — that is the maintainer's call, and the first-fire toast plus two off switches (Settings → Git, gear popover) are the mitigation; the notice's seen-marker is versioned if the copy or behavior meaningfully changes later.

## Assumptions stated in lieu of open questions

- 1000 ms dwell and a ~2 s PR-sync batch window are starting values, named constants, not contracts.
- Auto-view marks are visually identical to manual marks (no "auto" badge). The suppression rule makes the distinction behaviorally unnecessary, and a badge would double the header states for no decision the reviewer can act on differently.
- Demo/standalone mode (no `isApiMode`): the core runs (marks apply in-session), drafts and PR sync are naturally absent — no special casing.
