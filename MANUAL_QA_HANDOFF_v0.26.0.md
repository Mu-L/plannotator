# Manual Browser QA Handoff — Plannotator v0.26.0 Release Candidate

You are testing the release candidate for Plannotator v0.26.0. This document tells you what the product is, how to launch each surface, and exactly which workflows to walk through in the browser. Report pass/fail per workflow with notes.

## What Plannotator is

Plannotator is a local review UI for AI coding agents. When an agent (Claude Code, OpenCode, Pi, etc.) produces a plan, a code diff, or a document, Plannotator spins up a **local web server** and opens a **browser page** where a human reviews it: reading, selecting text, attaching annotations, and finally approving or sending feedback back to the agent. Three surfaces share one design system:

1. **Plan review** — an agent's markdown plan; the human approves or denies with annotated feedback.
2. **Code review** — a git diff viewer (file tree, per-line annotation, AI helpers); feedback goes back to the agent session.
3. **Annotate** — any markdown/text/HTML file, URL, or folder; annotations become structured feedback.

Servers bind to `localhost` on a port you choose via `PLANNOTATOR_PORT`. Settings persist in **cookies** (not localStorage) because ports change between sessions — this matters when you test persistence. Every session writes version history under `~/.plannotator/`.

## Setup

The release-candidate binary is already installed: `plannotator --version` should print `plannotator dev`. Work from the repo directory:

```bash
cd /Users/ramos/plannotator/plannotator
```

Launch commands are given per workflow below. Use the port given in each section so you never collide with other running tests. The browser does not open automatically if `PLANNOTATOR_SKIP_BROWSER_OPEN=1` is set — set it, and navigate your browser to `http://localhost:<port>` yourself.

## What changed in this release (where to look hardest)

Nine changes since v0.25.0. The ones with browser-visible surface:

- **Review search** (#1152): reopening search with Cmd+F now selects the existing query text.
- **Abandoned gate sessions** (#1143): a `--gate` annotate session whose browser tab closes auto-dismisses after ~30s; a reconnect within the grace window cancels that.
- **Claude Opus 5** (#1151): appears in the Ask AI model picker and review-agent model dropdowns.
- **Codex deferral** (#1145): opening a review no longer launches Codex; the Codex model list populates when you open the Ask AI panel or select Codex.
- **pi-todos mirror** (#1139): Pi-only, no browser surface — skip.
- Annotate-last, Amp/Droid, and Pi crash fixes: no browser surface — skip.

---

## Workflow A — Plan review round-trip (CRITICAL)

```bash
PLANNOTATOR_SKIP_BROWSER_OPEN=1 PLANNOTATOR_PORT=39200 plannotator <<'EOF'
{"session_id":"manual-qa","transcript_path":"/tmp/x.jsonl","cwd":"/Users/ramos/plannotator/plannotator","hook_event_name":"PermissionRequest","tool_name":"ExitPlanMode","tool_input":{"plan":"# QA test plan\n\nA plan for manual testing.\n\n## Steps\n\n- [ ] First step with `code`\n- [ ] Second step\n\n| Col A | Col B |\n|---|---|\n| 1 | 2 |\n\n> [!TIP]\n> A callout block.\n"}}
EOF
```

The command blocks until you decide in the browser (`http://localhost:39200`). Verify:

1. Plan renders: heading, task list, table (with its copy toolbar on hover), and the TIP callout.
2. Select a sentence → floating toolbar appears → add a **comment** annotation with some text.
3. Select other text → mark as **deletion** (strikethrough).
4. Add a **global comment** from the bottom bar.
5. Click **Approve** → the terminal prints a JSON decision containing `"behavior":"allow"` and the plan echoed back. Exit code 0.
6. Re-run the command, this time click **Request Changes / Deny** with feedback → terminal JSON contains `"behavior":"deny"` and your feedback text, including your annotations rendered as readable feedback.

**Pass** = both decisions round-trip with annotations intact, nothing rendered broken.

## Workflow B — Code review (CRITICAL)

```bash
PLANNOTATOR_SKIP_BROWSER_OPEN=1 PLANNOTATOR_PORT=39202 plannotator review
```

At `http://localhost:39202`:

1. Default view is the **Git status** panel (Committed / Changes / Untracked sections). Toggle to **Tree** and **Commits** views; Commits shows linear history — click a commit, its diff opens with the commit message rendered above.
2. Open a changed file; select code lines → annotate with a comment.
3. **Cmd+F** (or the search button): type a query, close search, press Cmd+F again → **the existing text should be focused and fully selected** so typing replaces it (this is new; regression here matters).
4. Expand diff context on a file (the +/− expanders) — file content loads.
5. Send Feedback with your annotation → terminal receives the feedback text; server exits.

**Pass** = sections render, annotations attach to the right lines, search select-on-reopen works, feedback round-trips.

## Workflow C — Annotate a file + version diff

```bash
PLANNOTATOR_SKIP_BROWSER_OPEN=1 PLANNOTATOR_PORT=39204 plannotator annotate README.md
```

1. File renders as markdown. Annotate a paragraph.
2. Send Annotations → terminal receives them.
3. Append a line to README.md (`echo "QA temp line" >> README.md`), re-run the same command → a **+N/−M diff badge** should appear (version history diff against the previous open). Click it: green/red/yellow diff view. Revert your edit afterward (`git checkout -- README.md`).

## Workflow D — Gate session + auto-dismiss (NEW BEHAVIOR)

```bash
PLANNOTATOR_SKIP_BROWSER_OPEN=1 PLANNOTATOR_PORT=39206 plannotator annotate README.md --gate --json
```

1. The UI shows an **Approve** button (gate mode). Click Approve → terminal prints a one-line JSON record with `"decision":"approved"`, exit 0.
2. Re-run. This time open the page, then **close the tab entirely**. Wait ~40 seconds. The terminal should print `"decision":"dismissed"` on its own — the abandoned session self-dismissed.
3. Re-run once more. Open the page, close the tab, **reopen `http://localhost:39206` within ~20 seconds** → the session must still be alive (no dismissal while you're reconnected). Then click the explicit Close/X → `"decision":"dismissed"`.

**Pass** = approve works, abandonment dismisses after the grace window, a quick reconnect cancels dismissal. This is brand-new logic — test it carefully.

## Workflow E — Annotate URL and folder

```bash
PLANNOTATOR_SKIP_BROWSER_OPEN=1 PLANNOTATOR_PORT=39208 plannotator annotate https://example.com
PLANNOTATOR_SKIP_BROWSER_OPEN=1 PLANNOTATOR_PORT=39210 plannotator annotate docs/ 2>/dev/null || PLANNOTATOR_SKIP_BROWSER_OPEN=1 PLANNOTATOR_PORT=39210 plannotator annotate adr/
```

URL: page content renders (fetched via Jina Reader). Folder: a file browser opens; pick a markdown file; it renders and is annotatable.

## Workflow F — Sidebar, settings, persistence

In any plan/annotate session:

1. Sidebar: **Table of Contents** navigates on click; **Version Browser** lists versions; **Archive** tab lists past plan decisions.
2. Open Settings: set an identity name, toggle theme (light/dark — both must be readable), enable Vim mode.
3. Kill the server, relaunch on a **different port** → settings must persist (they're cookies, domain-scoped). Identity, theme, and Vim toggle should all survive.
4. Vim mode: `j`/`k` moves the block cursor. KNOWN ISSUE, do not report: at the extreme top/bottom the cursor can sit under the floating HUD bars (#1153, fix in flight).

## Workflow G — Ask AI surface (model pickers)

In a code review session, open the **Ask AI** panel:

1. Provider picker lists detected providers. With Claude selected, the model dropdown must include **Opus 5** (new) alongside Sonnet 5 / Opus 4.8 etc.
2. If Codex is installed: selecting Codex should populate its real model list shortly after the panel opens (it activates on your gesture now — a brief fallback list flashing first is acceptable; a permanently stuck single-entry list is a FAIL).
3. Optionally ask a trivial question with Claude to confirm streaming works.

## Workflow H — Share URL

In a plan session with 2–3 annotations: Share → copy URL → open it in a fresh tab (or incognito). The plan AND annotations must restore from the URL alone (server not required for rendering). Author attribution shows if identity was set.

## Workflow I — First-run experience

Clear cookies for localhost (or use a fresh browser profile), open a code review session: the first-run dialog chain should appear one at a time (guided-reviews intro → look-and-feel chooser → review setup), never stacked, each dismissible. After dismissal, reload → they must not reappear.

---

## Known issues — do NOT report these

- Vim cursor under HUD bars at document edges (#1153; fix pending in #1154).
- Browser tooltip clipping at mobile widths (pre-existing).
- Table print layout inside `overflow-x-auto` wrappers (pre-existing).
- The `--render-html` annotate surface edge-pins vim navigation (out of scope).

## Reporting

For each workflow A–I: **PASS / FAIL / BLOCKED** plus one line of notes; for failures add repro steps and a screenshot. Anything broken that involves the round-trip decisions (A5, A6, B5, D) is release-blocking — flag those first.
