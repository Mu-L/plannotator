# Welcome to Plannotator

Your first assignment is manual QA on the v0.26.0 release candidate. Before you touch that, learn the product. You cannot tell broken from working if you do not know what working looks like, and most of what we need you to catch is the kind of wrong that still renders fine.

Budget roughly a day for reading and playing, then a day for the QA pass. Do not start the QA script early. A rushed pass that misses a real bug costs more than the day you saved.

---

## What Plannotator is

Coding agents write plans and diffs. Reviewing those inside a terminal is miserable. Plannotator opens a real browser UI at the moment a review is needed, lets you mark up the content, and sends your feedback back to the agent.

The important part: **it is a gate, not a viewer.** When an agent asks to exit plan mode, Plannotator intercepts that request and holds it. Nothing proceeds until a human approves or rejects. The agent is literally blocked on your browser tab.

That framing explains most design decisions you will run into. A session is short-lived, tied to one decision, and its whole job is to return an answer.

---

## The four modes

You will be testing all of these, so learn to tell them apart.

**Plan review.** An agent calls `ExitPlanMode`. A hook fires, Plannotator starts a server, opens a browser, and shows the plan as rendered markdown. You approve, or you annotate and deny. Denial sends your notes back and the agent revises. Resubmissions get a version diff so you can see what changed.

**Code review.** You run `/plannotator-review`. It captures the current diff and opens a browser diff viewer where you can comment on lines, suggest replacement code, and launch AI review agents. Feedback goes back to the agent session.

**Annotate.** You point it at a file, a URL, or a folder, and mark it up. Works on markdown, HTML, plain-text config formats, and web pages fetched and converted on the fly.

**Archive.** A read-only browser for past plan decisions.

---

## Read these, in this order

1. **`README.md`** at the repo root. Start at "How it works" (line 328). Skim the rest.
2. **`CLAUDE.md`** at the repo root. This is the real architecture document. Read the whole thing. It is long and worth it.
3. **The docs site**, `apps/marketing/src/content/docs/`. Specifically `getting-started/quickstart.md`, `guides/hook-integration.md`, and `reference/environment-variables.md`.

Then read the two QA documents so you know what is coming:

4. **`MANUAL_QA_HANDOFF_v0.26.0.md`** for the narrative view of what to test and why.
5. **`MANUAL_QA_v0.26.0.md`** for the exact steps you will execute.

---

## Get it running yourself

Reading is not enough. Install it and use it on a real task before you test it.

```bash
bun install
bun link          # makes the global `plannotator` command use this checkout
```

Then use it normally for a few hours. Write a plan with an agent and approve it. Deny one and watch the revision come back. Review a real diff. Annotate a markdown file. Break things on purpose and see what the error looks like.

By the end you should be able to answer: what does a healthy session look like, start to finish?

---

## Five things that will bite you

**Ports are random.** Every session picks a new port, which is why settings live in cookies rather than local storage. If a setting seems not to persist, check whether you are on the same port.

**There are two server implementations.** `packages/server/` is the Bun one used by Claude Code and OpenCode. `apps/pi-extension/server/` is a Node mirror with the same API. Any server change has to land in both. If you find a bug in one, check the other before reporting.

**Build order is not optional.** The hook build copies pre-built HTML from the review app. Run them out of order and you will test stale code and waste a day chasing a ghost:

```bash
bun run --cwd apps/review build && bun run build:hook
```

**The bundles are single-file and huge.** Around 23MB for plan review, 18MB for code review, everything inlined. This is deliberate. Do not report it as a bug.

**It runs on many hosts.** Claude Code, OpenCode, Pi, Codex, Amp, Droid, Kiro, Gemini, Copilot. Behavior differs between them. When you report something, always say which host you were on.

---

## Where to look hardest in v0.26.0

Recent work clusters here, so this is where new bugs live:

- **Edit mode** (`#1193`), off by default behind a Settings flag. Edit code in place and the changes become suggestions.
- **Guided review virtualization** (`#1158`, `#1161`). Only 8 file viewers stay mounted at once no matter how many files a guide has. Watch for blank cards or stutter while scrolling.
- **Colorblind themes** (`#1192`).
- **OpenCode 2 support** (`#1194`).
- **Uninstall** (`#1170`, `#1177`), including whether it preserves user data.
- **Installer opt-outs** (`#1178`), plus the late additions: `--skip-skills` and the checkout guard (`#1201`).
- **Large-file diff bounding** (`#1167`, `#1205`). A huge changed file should become a stub, never a hung or blank review.

Automated QA already ran across 24 areas. It cleared most of this. What it could not do is look at a screen, which is exactly why you exist. Hover states, color rendering, scroll feel, and whether the thing is actually pleasant to use are yours.

---

## Then run the QA

Once you can explain the four modes to someone else without looking anything up, open `MANUAL_QA_v0.26.0.md` and work through it top to bottom.

Two rules that matter more than the rest:

**Follow the isolation setup exactly.** The script builds its own worktree, its own data directory, and a sandbox home. This keeps your testing away from real user data. Do not skip it and do not point anything at your actual `~/.plannotator`.

**Report what you saw, not what you concluded.** "The diff panel flashed white for about a second when I switched files, on OpenCode, macOS Chrome" is useful. "Rendering is broken" is not. Screenshots for anything visual.

Log every result in the table at the end, including the passes. A pass you did not record reads as a test you did not run.

---

## When you are stuck

Ask. Early. Half of what looks like a bug in this codebase is a host difference or a stale build, and both are faster to rule out with a second pair of eyes than alone.
