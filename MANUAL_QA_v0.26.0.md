# Manual QA — v0.26.0 (agent-executable)

Written for a browser-integrated agent (local commands + browser control). Every test has exact
commands, browser steps, and PASS criteria. Fill the results table at the bottom as you go and
save screenshots to `$QA/shots/`.

Supersedes `MANUAL_QA_HANDOFF_v0.26.0.md` (stale, pre-dates this cycle).

---

## 0. Ground rules

- **Never touch the real `~/.plannotator`.** Every server/CLI run gets `PLANNOTATOR_DATA_DIR="$QA/data"`.
  The ONLY exception is section G (uninstall), which uses its own fake `$HOME` sandbox.
- **Never kill processes by name** (`pkill bun` etc.) — kill only PIDs you started. Another
  agent's demo server may be running on this machine (port 49684); leave it alone.
- Use a **fresh browser profile** (no cookies) so first-run behavior is real. Settings persist in
  cookies per-port, so keep using the same profile across tests once first-run is verified.
- Servers bind random ports by default. For a predictable URL use
  `PLANNOTATOR_REMOTE=1 PLANNOTATOR_PORT=<port>` (also prints the URL on stderr).
- An automated QA workflow already covered API/logic-level checks. Your job is what only
  eyes-in-a-browser can judge: rendering, feel, layout, color, interaction.

## 1. Setup (isolated worktree)

```bash
export QA=/tmp/plannotator-qa-v026
mkdir -p "$QA/shots" "$QA/data"
cd /Users/ramos/plannotator/plannotator
git worktree add "$QA/wt" origin/main
cd "$QA/wt"
bun install
bun run --cwd apps/review build && bun run build:hook
export PLN="bun $QA/wt/apps/hook/server/index.ts"
```

Seed two fixture repos:

```bash
# small repo for basic review
mkdir -p "$QA/repo-small" && cd "$QA/repo-small" && git init -q
printf 'export function add(a,b){\n  return a+b;\n}\n' > math.ts
git add -A && git -c user.email=qa@x -c user.name=qa commit -qm base
printf 'export function add(a: number, b: number): number {\n  return a + b;\n}\nexport const VERSION = 2;\n' > math.ts

# large repo for virtualization (#1161): 45 files, real diffs
mkdir -p "$QA/repo-big" && cd "$QA/repo-big" && git init -q
for i in $(seq 1 45); do printf 'export const v%d = %d;\nfunction f%d(){ return %d; }\n' $i $i $i $i > "file$i.ts"; done
git add -A && git -c user.email=qa@x -c user.name=qa commit -qm base
for i in $(seq 1 45); do printf 'export const v%d = %d0;\nfunction f%d(){ return %d * 2; }\nexport const extra%d = true;\n' $i $i $i $i $i > "file$i.ts"; done
```

---

## A. Plan review (true hook path)

The hook reads a PermissionRequest JSON on stdin and prints a decision JSON on stdout.

```bash
cd "$QA/wt"
cat > "$QA/plan-input.json" << 'EOF'
{"tool_name":"ExitPlanMode","tool_input":{"plan":"# QA Plan v0.26\n\n## Steps\n1. Check `packages/server/index.ts` rendering\n2. A table:\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n> [!TIP]\n> Callout renders.\n\nReference link test: [ref][1]\n\n[1]: https://example.com\n"}}
EOF
PLANNOTATOR_DATA_DIR="$QA/data" $PLN < "$QA/plan-input.json" > "$QA/plan-decision.json" 2> "$QA/plan-stderr.log" &
echo $! > "$QA/plan.pid"
```

Browser opens automatically (local mode). In the browser:

1. **A1** Plan renders: heading, numbered list, table, TIP callout, and the **reference link
   `ref` renders as a real link** (#1168 — in 0.25.1 it was raw text). Screenshot `a1.png`.
2. **A2** Select text → toolbar appears → add a comment with text. Select other text → Delete
   (redline). Add a global comment.
3. **A3** Open Settings → confirm tabs render, Theme tab lists **Colorblind** (#1192). Switch to
   it: diff-agnostic UI recolors; code block syntax recolors. Screenshot `a3.png`. Switch back.
4. **A4** Click **Deny** with feedback text. Then check:
   `cat "$QA/plan-decision.json"` → `behavior":"deny"` and your comments present in the message.
   PASS = decision JSON contains all three annotations (comment, deletion, global).
5. **A5** Re-run the same command, this time **Approve**. Decision JSON has `"behavior":"allow"`
   and (Claude Code path) echoes the plan in `updatedInput`.

## B. Code review — small repo

```bash
cd "$QA/repo-small" && PLANNOTATOR_DATA_DIR="$QA/data" $PLN review 2> "$QA/rev-stderr.log" &
echo $! > "$QA/rev.pid"
```

1. **B1 First-run chain** (fresh profile): dialogs appear in order — guide intro → look-and-feel →
   review setup — and **never stack**. Choose Git-status + since-base. Screenshot `b1.png`.
2. **B2** Git status panel shows Committed/Changes/Untracked sections; toggle to Tree and to
   Commits; commit click opens its diff with the message rendered as markdown.
3. **B3** Diff renders `math.ts` split view; toggle Unified; toggle hide-whitespace.
4. **B4 Pierre visual pass (the 1.2.8→1.3.2 gate):** Settings → Display/Editor tab → set line
   background intensity to each of subtle/normal/strong; at each, **hover an added line and a
   deleted line** — hover tint must read as a subtle deepening, not a jarring jump — in **both
   light and dark** (toggle theme). Screenshots `b4-<intensity>-<mode>.png` (12 total).
   PASS = no garish/absent hover states, no unreadable text on any tint.
5. **B5 Colorblind theme on a diff**: switch theme to Colorblind — added lines render **blue-ish**,
   deleted **orange-ish**, `+`/`-` gutter signs legible, syntax colors change. Screenshot `b5.png`.
   Switch back.
6. **B6 Annotations**: line comment via gutter/selection; file comment; suggestion via the
   suggestion modal (edit the proposed text); a global comment in the sidebar.
7. **B7 Copy feedback shortcut** (#1155): press `Cmd+Shift+Y` → toast "Feedback copied" → paste
   into a scratch buffer: contains your annotations, and the suggestion shows **both**
   `**Replaces:**` and `**Suggested code:**` fenced blocks (#1187/#1193 format).
8. **B8** Send Feedback → server prints the feedback and exits. Verify `$QA/rev-stderr.log` /
   terminal shows it. Kill leftovers if any: `kill $(cat "$QA/rev.pid") 2>/dev/null`.

## C. Edit mode (flag-gated, #1193)

```bash
cd "$QA/repo-small" && PLANNOTATOR_DATA_DIR="$QA/data" $PLN review 2>/dev/null & echo $! > "$QA/edit.pid"
```

1. **C1** Settings → **Editor** tab → first toggle is **"Edit Code to Suggest"**, labeled
   experimental, **off by default**. With it OFF: no Edit button anywhere. Turn ON.
2. **C2** File header now shows **Edit** at the far right (next to the dropdown). Click it.
   The HUD strip appears **below the header**: `✎ Editing · EXPERIMENTAL · n changes` left,
   `Suggest / Discard` right. Header itself shows no duplicate controls. Screenshot `c2.png`.
3. **C3** Type into a green line — hunks reshape live; the HUD change-count updates after a pause.
4. **C4** Select some code → popover appears → **Make annotation** → comment box opens with the
   selection quoted → save. Annotation card appears. **No wavy underlines anywhere** (markers
   were removed by design).
5. **C5** Click **Suggest** → diff snaps back pristine; a suggestion annotation exists with your
   net edit. Card has **no green left border** (accent removed by design); the SUGGESTION header
   is the identity. Screenshot `c5.png`.
6. **C6** Enter edit again, type, click **Discard** → everything restores, no annotation.
7. **C7** Enter edit, type, then change file **sort order** in the panel → a prompt offers to
   keep your edits as suggestions. Decline → clean. (Recovery flow.)
8. **C8** Export feedback (`Cmd+Shift+Y`): the edit-derived suggestion carries `Replaces:` +
   `Suggested code:` and, for the selection annotation, `Highlighted text:`.
   Kill: `kill $(cat "$QA/edit.pid") 2>/dev/null`.

## D. Guided-review virtualization (#1161 gate) — big repo

```bash
cd "$QA/repo-big" && PLANNOTATOR_DATA_DIR="$QA/data" $PLN review 2>/dev/null & echo $! > "$QA/big.pid"
```

1. **D1** All-files view with 45 files: **fast scroll top-to-bottom twice**. PASS = no blank
   gaps that persist, no layout jumps, scroll position stable when you stop, file headers stay
   sticky, expanding/collapsing a file mid-list doesn't teleport the scroll.
2. **D2** Stage a file via the header chip (`Git Add`) → chip updates immediately; unstage → same.
3. **D3** Open the search (`Cmd+F` app search if present, or the panel search): type a symbol,
   matches highlight across files while scrolling.
4. **D4** With Guided Review available (AI off is fine — skip generation), verify the plain
   all-files surface has **no Edit buttons inside Guided Review cards** if you generate one
   (edit mode is deliberately excluded there). If no AI configured, note "guide generation
   skipped" and move on.
   Kill: `kill $(cat "$QA/big.pid") 2>/dev/null`.

## E. Annotate mode

```bash
printf '# Notes\n\nSome **markdown** here.\n\n```py\nprint(1)\n```\n' > "$QA/notes.md"
cd "$QA" && PLANNOTATOR_DATA_DIR="$QA/data" $PLN annotate notes.md 2>/dev/null & echo $! > "$QA/ann.pid"
```

1. **E1** Renders; annotate a line; Send Annotations → output contains it. Kill PID.
2. **E2 Tolerant args** (#1183, terminal-only, no browser):
   - `$PLN annotate notes.md please` (from `$QA`) → resolves and boots (kill it).
   - `printf x > "$QA/a.md"; printf y > "$QA/b.md"; $PLN annotate a.md b.md` → **exit 1**, error
     names both candidates.
   - `$PLN annotate the meeting notes` → **exit 0**, stdout is an agent-addressed handoff
     mentioning re-running with a concrete path.
   - `$PLN annotate nope.md` → **exit 1**, `File not found`.
   - `$PLN annotate nope.md --gate --json --require-approval` → **exit 2**, stdout empty.
3. **E3 Folder + HTML**: `$PLN annotate "$QA"` → file browser lists the md files (browser opens;
   pick one; kill). `printf '<h1>Hi</h1><p>para</p>' > "$QA/p.html"; $PLN annotate p.html` →
   renders as HTML (kill).

## F. Remote URL visibility

```bash
cd "$QA/repo-small" && PLANNOTATOR_DATA_DIR="$QA/data" PLANNOTATOR_REMOTE=1 PLANNOTATOR_PORT=19876 \
  $PLN review 2> "$QA/remote.log" & echo $! > "$QA/remote.pid"
sleep 3 && cat "$QA/remote.log"
```

1. **F1** PASS = stderr contains the session URL (with port 19876) and a port-forwarding hint.
   Open the URL manually in the browser — app loads. Kill PID.

## G. Uninstall (sandbox HOME — the only test allowed to simulate a real install)

```bash
export SBHOME="$QA/sandbox-home"; mkdir -p "$SBHOME"
# install for real into the sandbox (network needed; installs latest release binary):
HOME="$SBHOME" bash "$QA/wt/scripts/install.sh" 2>&1 | tail -20
# seed fake user data:
mkdir -p "$SBHOME/.plannotator/plans"; echo test > "$SBHOME/.plannotator/plans/keep.md"
# dry run:
HOME="$SBHOME" "$SBHOME/.local/bin/plannotator" uninstall --dry-run
# real:
HOME="$SBHOME" "$SBHOME/.local/bin/plannotator" uninstall --yes
```

1. **G1** Dry-run lists removals and **writes nothing** (`keep.md` still there after).
2. **G2** Real uninstall removes binary/skills but **preserves `$SBHOME/.plannotator/plans/keep.md`**
   (data preserved by default). PASS = file survives, binary gone.
   Note: the installed binary is v0.25.1 (latest release) — uninstall exists only if the release
   shipped it; if the subcommand is unknown, run the uninstall from source instead:
   `HOME="$SBHOME" $PLN uninstall --yes` and note that in results.

## H. Print + misc quick passes

1. **H1** In a plan view, `Cmd+P` print preview: content readable, no catastrophic clipping
   (known acceptable: wide tables scroll-clip). Screenshot `h1.png`.
2. **H2** Toggle Vim mode in Settings; `j/k` moves the block cursor; no console errors
   (open devtools console during the session; report any red).
3. **H3** Archive: `PLANNOTATOR_DATA_DIR="$QA/data" $PLN archive` — after your A-section runs,
   saved decisions appear; open one; verify **read-only** (no annotation toolbar on selection);
   Done closes. (#1171)

## I. Late-cycle merges (installer opt-out + guard, OpenCode install weight, big-diff bound)

These four landed after the rest of this script was written (#1201, #1203, #1204, #1205).
I1 and I2 use a second sandbox HOME, same isolation rule as section G.

```bash
export SBHOME2="$QA/sandbox-home-i"; mkdir -p "$SBHOME2"
```

1. **I1** Skills opt-out: `HOME="$SBHOME2" bash "$QA/wt/scripts/install.sh" --skip-skills 2>&1 | tail -25`
   PASS = exit 0, binary at `$SBHOME2/.local/bin/plannotator`, output contains
   `Skills: skipped (--skip-skills)`, and `$SBHOME2/.claude/skills` has no plannotator-* entries.
2. **I2** Checkout guard: `HOME="$SBHOME2" bash "$QA/wt/scripts/install.sh" --version v0.0.0-nope 2>&1 | tail -5; echo "exit=$?"`
   PASS = exit 1 and an explicit fetch error; FAIL if it prints a success banner (#1201's bug was
   exactly this: reporting success on a failed skills checkout).
3. **I3** OpenCode install weight: from the worktree,
   `cd "$QA/wt/apps/opencode-plugin" && npm pack --ignore-scripts --pack-destination "$QA"` then
   `mkdir -p "$QA/oc-install" && cd "$QA/oc-install" && npm install "$QA"/plannotator-opencode-*.tgz`.
   PASS = install completes and `"$QA/oc-install/node_modules/bun"` does **not** exist
   (pre-#1204 it pulled a ~50MB bun package).
4. **I4** Big-diff bound: in a scratch repo, commit a >6MB text file
   (`base64 /dev/urandom | head -c 7000000 > big.txt`), modify it, run a review session.
   PASS = the file appears as an excluded/binary-style stub (not 7MB of rendered diff), the
   server stays responsive, and other changed files in the same diff render normally. (#1205)

## Results table (fill in)

| ID | PASS/FAIL/SKIP | Notes |
|----|----------------|-------|
| A1–A5 | PASS | Plan rendering, hover actions, three annotation types, Colorblind theme, deny feedback, and follow-up approval all worked. |
| B1–B8 | FAIL | B1–B5 and B7–B8 pass. B6 fails because the annotations sidebar has no entry point for creating the required global code-review comment; line, file, and suggestion comments work. |
| C1–C8 | FAIL | C1–C5 and C8 pass; C7's recovery prompt appeared, but the native dialog blocked inspection of the final Decline result. C6 fails: Discard exits edit mode but leaves the newly typed code visible instead of restoring the pristine diff. |
| D1–D4 | PASS | Two fast 45-file scroll passes were stable with no persistent gaps/jumps; mid-list collapse, stage/unstage, and search worked. Guide generation was not run. |
| E1–E3 | PASS | Markdown annotation round-tripped; tolerant args returned 1/0/1/2 as specified; folder browser and raw HTML rendering worked. |
| F1 | PASS | stderr showed `http://localhost:19876`, the forwarding hint, and a share URL; the local URL loaded manually. |
| G1–G2 | PASS | Used the documented source fallback because installed v0.25.1 did not expose useful uninstall output. Dry-run preserved targets/data; real uninstall removed the binary/integrations and preserved `plans/keep.md`. |
| H1–H3 | SKIP / PASS | H1 print preview could not be inspected or captured through the in-app browser surface (the page itself remained readable). H2 and H3 pass: Vim j/k navigation worked with no console warnings/errors; archive decisions were readable and read-only, and Done closed. |
| I1–I4 | FAIL | I1, I3, and I4 pass. I2 correctly stops with an explicit curl 404 and no success banner, but returns exit 56 rather than the required exit 1. |

## Teardown

```bash
for f in "$QA"/*.pid; do kill "$(cat "$f")" 2>/dev/null; done
git -C /Users/ramos/plannotator/plannotator worktree remove "$QA/wt" --force
# keep $QA/shots and the results for the report
```

Deliver: the filled table, all screenshots, the devtools-console note from H2, and a one-paragraph
gut verdict: "would you ship this to strangers."
