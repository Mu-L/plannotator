Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.21.3](https://github.com/backnotprop/plannotator/releases/tag/v0.21.3)   | File comments in code review, unified click-to-highlight comments, VS Code clipboard/keyboard bridge, Codex Ask AI on app-server transport, CLI subcommand help |
| [v0.21.2](https://github.com/backnotprop/plannotator/releases/tag/v0.21.2)   | Custom reviews as Agent Skills, Cursor + OpenCode review engines, whole-file/general findings, deleted-annotation fix, Codex Ask AI outside git repos |
| [v0.21.1](https://github.com/backnotprop/plannotator/releases/tag/v0.21.1)   | Annotate-last blank-page fix on multi-message sessions                                                                            |
| [v0.21.0](https://github.com/backnotprop/plannotator/releases/tag/v0.21.0)   | Direct document editing in annotate mode, live git-status file tree, in-app agent terminal, open files in external apps, HTML renders as HTML |
| [v0.20.3](https://github.com/backnotprop/plannotator/releases/tag/v0.20.3)   | Annotations no longer lost when clicking away, off-screen indicator for open comments                                            |
| [v0.20.2](https://github.com/backnotprop/plannotator/releases/tag/v0.20.2)   | Pierre CodeView all-files review, large-PR pipeline and instant-open checkout, unified agent engine selection, Pi programmatic plan mode |
| [v0.20.1](https://github.com/backnotprop/plannotator/releases/tag/v0.20.1)   | Pi extension install hotfix (pinned `@pierre/diffs` after a broken upstream release)                                             |
| [v0.20.0](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0)   | Multi-repo workspace reviews, semantic diff overview, UI 2.0 themes and plan look chooser, leaner single-source skill install   |
| [v0.19.27](https://github.com/backnotprop/plannotator/releases/tag/v0.19.27) | Kiro CLI integration, Glimpse native window, annotate-last message picker                                                        |
| [v0.19.26](https://github.com/backnotprop/plannotator/releases/tag/v0.19.26) | Amp plugin production fixes, Mermaid rendering fix, Settings flicker fix, update notification toast and shimmer                   |
| [v0.19.24](https://github.com/backnotprop/plannotator/releases/tag/v0.19.24) | Amp integration, configurable data directory, Auto Mode permission option, Pi plan approval fix                                  |

</details>

---

## What's New in v0.21.4

This release adds Markdown math rendering and continues the code-review pass from v0.21.2 and v0.21.3. The PR review experience is consolidated into a single Overview panel where the description and individual comments are now annotatable, and the "Copy agent instructions" onboarding reaches code review at parity with plan mode. Five PRs land, including one from returning contributor @ishowman.

### Markdown Math Rendering

Plans, annotated documents, and PR content now render LaTeX math. Inline math written as `$…$` or `\(…\)` and display math written as `$$…$$` or `\[…\]` typeset through KaTeX, with the fonts bundled into the app so equations render offline. Rendered formulas are also first-class annotation targets: you can drag-select across prose and a formula together, or redline a whole equation, and the selection is captured like any other annotation.

Because the same renderer handles arbitrary plan text and untrusted PR descriptions, it is deliberate about what counts as math. A stray or unterminated `$$` (or an informal amount like `$$100k`) no longer runs on and swallows the rest of a document — an unclosed delimiter is treated as ordinary text, so headings and paragraphs below it keep their structure and stay annotatable. Dollar amounts in prose such as `$5-$10`, `$50,000-$100,000`, or `$5/mo … $10/mo` are left as literal text rather than being mistaken for inline math.

PR [#878](https://github.com/backnotprop/plannotator/pull/878) closing [#831](https://github.com/backnotprop/plannotator/issues/831), by @ishowman — requested by @XxxXMil.

### PR Overview Panel

Reviewing a pull request used to mean three separate dock tabs — Summary, Comments, and Checks — behind three header buttons. They are now one **PR Overview** panel: the description and checks stack on the left, comments fill the right, and checks collapse into a progressive-disclosure section with a colored progress label. The comments view gained author avatars, a single-row toolbar with search and filters, a "hide bots" toggle, and background refresh so the discussion and check state stay current while you review.

The description and comments are also annotatable. Select text in the PR description and leave a comment, or click "Annotate" on any comment card to attach a note to the whole comment. These notes show in the Annotations sidebar under their own groups, count toward the review, and ship to the agent — with the full comment body quoted alongside your note, since the agent can't see the PR discussion on its own. Prose notes stay bound to the PR they were made on: switching to another PR in place hides them from view and export rather than carrying them onto the new PR, and switching back brings them right back. The description renders through the full shared block renderer, so tables, callouts, code, and embedded media (images, `<video>`, and `<picture>`) all display inline.

PR [#981](https://github.com/backnotprop/plannotator/pull/981), by @backnotprop.

### Copy Agent Instructions in Code Review

Plan mode has a "Copy agent instructions" action that hands an agent the exact clipboard contract for posting annotations back into Plannotator. That onboarding now exists in code review too, at parity with plan mode: the review header menu offers "Agent Instructions" in a live session, and the copied payload documents how to read the changeset, derive line numbers from the diff, and POST line-, file-, and general-scoped comments (including code suggestions). The backend already accepted these; this closes the missing on-ramp.

PR [#983](https://github.com/backnotprop/plannotator/pull/983), by @backnotprop — suggested by @hakunin on X.

### Additional Changes

- **Immediate feedback when launching a review agent** — clicking Run in Review Agents now shows a pending launch row and a "Starting" state right away, surfaces server-side launch failures instead of silently clearing the request, and hands off cleanly to the real job once it starts. PR [#980](https://github.com/backnotprop/plannotator/pull/980), by @backnotprop.
- **Annotation count badge in the plan and annotate header** — the annotations toggle in the shared plan/annotate header now shows a numeric count badge, matching the code-review header. PR [#979](https://github.com/backnotprop/plannotator/pull/979), by @backnotprop.
- **Sturdier media and delimiter parsing** — the shared markdown parser no longer lets an unclosed `<video>`/`<picture>` tag or a multi-line `<img>` swallow or garble the rest of a document, and `<picture>`/`<source>` and responsive `<img>` now render correctly. This hardens the same renderer the math and PR Overview work rely on.

## Install / Update

**macOS / Linux:**

```bash
curl -fsSL https://plannotator.ai/install.sh | bash
```

**Windows:**

```powershell
irm https://plannotator.ai/install.ps1 | iex
```

**Extra skills** (compound, setup-goal, visual-explainer), opt-in:

```bash
npx skills add backnotprop/plannotator/apps/skills/extra
```

**Claude Code Plugin:** Run `/plugin` in Claude Code, find **plannotator**, and click **"Update now"**.

**OpenCode:** Clear cache and restart:

```bash
rm -rf ~/.bun/install/cache/@plannotator
```

Then in `opencode.json`:

```json
{
  "plugin": ["@plannotator/opencode@latest"]
}
```

**Pi:** Install or update the extension:

```bash
pi install npm:@plannotator/pi-extension
```

**Droid:** Install via the plugin marketplace:

```
droid plugin marketplace add backnotprop/plannotator
droid plugin install plannotator@plannotator
```

**Amp:** Install the CLI first, then copy the plugin:

```bash
mkdir -p ~/.config/amp/plugins
curl -fsSL https://raw.githubusercontent.com/backnotprop/plannotator/main/apps/amp-plugin/plannotator.ts \
  -o ~/.config/amp/plugins/plannotator.ts
```

**Kiro CLI:** The installer auto-detects Kiro and installs skills automatically. After installing the CLI, launch with:

```bash
kiro-cli chat --agent plannotator
```

Upgrading from before v0.20.0? Read the [v0.20.0 release notes](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0) first; that release changed how skills install.

---

## What's Changed

- feat(ui): render markdown math by @ishowman in [#878](https://github.com/backnotprop/plannotator/pull/878)
- feat(review): PR Overview panel + description/comment annotations + media by @backnotprop in [#981](https://github.com/backnotprop/plannotator/pull/981)
- feat(review): add "Copy agent instructions" for external review comments by @backnotprop in [#983](https://github.com/backnotprop/plannotator/pull/983)
- fix(review): show pending agent job launches by @backnotprop in [#980](https://github.com/backnotprop/plannotator/pull/980)
- feat(annotate): show annotation count badge in plan/annotate header by @backnotprop in [#979](https://github.com/backnotprop/plannotator/pull/979)
- fix(ui): stop unclosed `<video>`/`<picture>` from swallowing the document by @backnotprop
- fix(review): scope PR description/comment notes to their PR by @backnotprop
- fix(ui): keep stray/unclosed math delimiters and dollar amounts from mangling text by @backnotprop

## Contributors

@ishowman built Markdown math rendering ([#878](https://github.com/backnotprop/plannotator/pull/878)), picking up the feature request in [#831](https://github.com/backnotprop/plannotator/issues/831) and implementing inline and display math with KaTeX, including selectable, annotatable formulas.

Thanks also to the community members whose requests shaped this release:

- @XxxXMil requested Markdown math formula rendering ([#831](https://github.com/backnotprop/plannotator/issues/831)), delivered in [#878](https://github.com/backnotprop/plannotator/pull/878).
- @hakunin suggested (on X) bringing the "Copy agent instructions" onboarding to code review, delivered in [#983](https://github.com/backnotprop/plannotator/pull/983).

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.21.3...v0.21.4
