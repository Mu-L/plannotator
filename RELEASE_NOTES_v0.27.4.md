Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.27.3](https://github.com/backnotprop/plannotator/releases/tag/v0.27.3)   | Folder watcher freeze fix on large repos, first SBOM-attested release pipeline                                                   |
| [v0.27.2](https://github.com/backnotprop/plannotator/releases/tag/v0.27.2)   | Mobile plan and code review, Codex CLI 0.147 fix, folder annotate cold-start, configurable markdown extensions |
| [v0.27.1](https://github.com/backnotprop/plannotator/releases/tag/v0.27.1)   | Open-in-editor launch fix, file headers respect Viewed/Git-add visibility toggles                                                |
| [v0.27.0](https://github.com/backnotprop/plannotator/releases/tag/v0.27.0)   | Call Flow analysis, --tailscale remote reviews, review panel remembers your view, Pi rebuild (breaking command rename), focus-mode shortcut |
| [v0.26.8](https://github.com/backnotprop/plannotator/releases/tag/v0.26.8)   | Placed comment markers on HTML pages, shift-click multi-select, live app annotation                                              |
| [v0.26.7](https://github.com/backnotprop/plannotator/releases/tag/v0.26.7)   | Pinpoint targets any element on HTML pages, smarter hover labels, zero-scan hit testing                                          |
| [v0.26.6](https://github.com/backnotprop/plannotator/releases/tag/v0.26.6)   | Fixed empty environment variables in sandboxed sessions (Bun 1.3.14 builds)                                                      |
| [v0.26.5](https://github.com/backnotprop/plannotator/releases/tag/v0.26.5)   | HTML pinpoint element annotations, durable annotate submissions, installer fallback for old git, vim HUD cursor fix              |
| [v0.26.4](https://github.com/backnotprop/plannotator/releases/tag/v0.26.4)   | Skill-menu hover jitter fix (same-day patch on v0.26.3)                                                                          |
| [v0.26.3](https://github.com/backnotprop/plannotator/releases/tag/v0.26.3)   | Skill references in comments with / or $, reachable remote session URLs, worktree switcher tooltips                              |
| [v0.26.2](https://github.com/backnotprop/plannotator/releases/tag/v0.26.2)   | Single-file diff tabs render fully, no more silently dropped review files, light/dark theme pairs, palette-matched code blocks   |
| [v0.26.1](https://github.com/backnotprop/plannotator/releases/tag/v0.26.1)   | GitButler 0.22.0 compatibility via capability-probed JSON flags                                                                   |

</details>

## What's New in v0.27.4

A Guided Review can now leave Plannotator. This release ships portable guide exports, share links on guides.show, and a guide CLI any agent can drive, alongside a favicon style switcher, jj support for Call Flow, GitLab artifact fixes in PR review, and a smoother call-flow Lens. Eighteen PRs, four from community contributors, two of them first-timers.

### Portable Guided Reviews and guides.show

Guided Reviews used to live and die inside your review session. Now a guide has three ways out:

**Download it.** Every guide gets a "Download portable guide" button that produces one HTML file containing the full guide and the diff it describes. It opens anywhere, renders exactly like the in-app guide with side-by-side diffs and per-section reviewed checkboxes, and needs no Plannotator install. The file stays small because it carries your content, not the renderer: the viewer loads from guides.show, pinned by filename and cryptographic checksum, so a tampered or wrong viewer never executes. Offline, the file degrades to a readable plain-text version of the guide.

**Share it.** "Create share link" uploads the guide to guides.show and hands you a link anyone can open in a browser. Shares are end-to-end encrypted by default: the key lives in the URL fragment after the `#`, which browsers never send to the server, so guides.show stores bytes it cannot read. You also get a one-time delete token, and "Remove link" works from the same dialog for as long as that Plannotator remembers the share. An optional "Allow link previews" checkbox stores the guide unencrypted so chat apps can show its title; that is a choice, never the default. Setting `PLANNOTATOR_SHARE=disabled` turns all of this off.

**Author it from anywhere.** The new `plannotator guide` subcommands (`list`, `export`, `share`, `unshare`) let any agent or script produce and publish a guide from a guide JSON and a patch, without a browser in the loop.

Saved guides from v0.27.x load unchanged. The share service runs on Cloudflare with add-only, content-hashed viewer publishing and per-IP rate limiting on creation.

- [#1324](https://github.com/backnotprop/plannotator/pull/1324), [#1327](https://github.com/backnotprop/plannotator/pull/1327), [#1328](https://github.com/backnotprop/plannotator/pull/1328), [#1329](https://github.com/backnotprop/plannotator/pull/1329), [#1330](https://github.com/backnotprop/plannotator/pull/1330), [#1336](https://github.com/backnotprop/plannotator/pull/1336), [#1337](https://github.com/backnotprop/plannotator/pull/1337) by @backnotprop

### Choose your favicon: Totman or the classic P

The browser-tab icon is now a setting. Appearance settings offer two styles with visual previews: Totman, the current mascot, and Classic P, the original Plannotator mark restored byte-for-byte from the pre-mascot era. The server remembers your choice and serves it directly, so tabs show the right icon from the first paint without flashing the default. Hosts that embed the published UI packages are unaffected unless they opt in.

- [#1325](https://github.com/backnotprop/plannotator/pull/1325) by @FNDEVVE

### Call Flow analysis on jj repositories

Call Flow previously required a plain Git checkout. Reviews running on jj (Jujutsu) colocated repos now get the same changed-call-path analysis: the jj snapshot is resolved to the underlying Git objects and fed to the same CallDiff engine, with the same per-file Lens and dock views. Diff collection is untouched; this only extends where the analysis can run.

- [#1312](https://github.com/backnotprop/plannotator/pull/1312) by @graemefolk

### GitLab PR artifacts fetch reliably and more safely

Reviewing GitLab merge requests with uploaded artifacts (screenshots, logs, design files) got a hardening pass. Uploads now fetch through the authenticated API with a strict rewrite that only touches real upload URLs, falls back to the original web route when a self-hosted GitLab predates the API route, maps 401/403 responses to a clear "run glab auth login" hint, and no longer serves HTML or JavaScript content types through the artifact proxy. A regression test pins the invariant that credentials never follow a cross-origin redirect.

- [#1228](https://github.com/backnotprop/plannotator/pull/1228) by @yuensunn

### The call-flow Lens stops fighting your scroll

Community feedback within hours of trying Call Flow in Safari: the per-file Lens popover closed randomly mid-scroll and popped open for every badge that passed under the cursor. Three causes, three fixes: the Lens's internal scroll no longer chains to the page when momentum hits its edge (the chain moved the popup out from under a stationary pointer, which read as a random close and was worst under Safari rubber-banding); hover now has a 100ms intent delay so drive-by badges stay closed; and an in-flight page scroll holds any pending close until the scroll settles.

Reported by Rustan (@acewhocares on X).

- [#1338](https://github.com/backnotprop/plannotator/pull/1338) by @backnotprop

### Additional Changes

- **Touch selection survives the comment composer.** On phones and tablets, dragging a multi-line range in a single-file diff no longer collapses the selection when the composer opens; the range you dragged is the range you comment on. [#1333](https://github.com/backnotprop/plannotator/pull/1333)
- **Skill picker works with screen readers.** The `/` and `$` skill reference menu now exposes real listbox semantics with option roles and active-descendant tracking, so assistive tech announces what Enter will insert, closing [#1233](https://github.com/backnotprop/plannotator/issues/1233). [#1316](https://github.com/backnotprop/plannotator/pull/1316) by @ashish921998
- **Blog: an interactive UI for the grill-me skill.** A new post on using `/plannotator-last` as the review surface for Matt Pocock's grill-me workflow, at [plannotator.ai](https://plannotator.ai). [#1321](https://github.com/backnotprop/plannotator/pull/1321), [#1322](https://github.com/backnotprop/plannotator/pull/1322), [#1323](https://github.com/backnotprop/plannotator/pull/1323), [#1332](https://github.com/backnotprop/plannotator/pull/1332)
- **Security page linked from the site footer.** [#1305](https://github.com/backnotprop/plannotator/pull/1305)

## Install / Update

**macOS / Linux:**

```bash
curl -fsSL https://plannotator.ai/install.sh | bash
```

**Windows:**

```powershell
irm https://plannotator.ai/install.ps1 | iex
```

**Claude Code Plugin:** Run `/plugin` in Claude Code, find **plannotator**, and click **"Update now"**.

**OpenCode:** Clear cache and restart:

```bash
rm -rf ~/.bun/install/cache/@plannotator
```

## What's Changed

- fix(comments): expose skill picker semantics to assistive tech by @ashish921998 in [#1316](https://github.com/backnotprop/plannotator/pull/1316)
- feat(review): jj support for Call Flow analysis by @graemefolk in [#1312](https://github.com/backnotprop/plannotator/pull/1312)
- blog: an interactive UI for the grill-me skill by @backnotprop in [#1321](https://github.com/backnotprop/plannotator/pull/1321)
- blog: grill-me post additions by @backnotprop in [#1322](https://github.com/backnotprop/plannotator/pull/1322)
- blog: repo link, image alt text, and larger blog type by @backnotprop in [#1323](https://github.com/backnotprop/plannotator/pull/1323)
- feat: Portable Guided Reviews, export, share links, agent-authored guides, guides.show by @backnotprop in [#1324](https://github.com/backnotprop/plannotator/pull/1324)
- guides-show: GitHub link in the landing page header by @backnotprop in [#1327](https://github.com/backnotprop/plannotator/pull/1327)
- guide-viewer: label agent harnesses in the generated-by line by @backnotprop in [#1328](https://github.com/backnotprop/plannotator/pull/1328)
- guide-viewer: readable on phones and tablets, desktop untouched by @backnotprop in [#1329](https://github.com/backnotprop/plannotator/pull/1329)
- seo: index live root blog pages by @backnotprop in [#1332](https://github.com/backnotprop/plannotator/pull/1332)
- guide: voice rules in the organizer prompt by @backnotprop in [#1330](https://github.com/backnotprop/plannotator/pull/1330)
- docs(marketing): link security page from footer by @backnotprop in [#1305](https://github.com/backnotprop/plannotator/pull/1305)
- fix(review): preserve dragged diff ranges on compact touch before commenting by @backnotprop in [#1333](https://github.com/backnotprop/plannotator/pull/1333)
- feat(ui): Totman/Classic P favicon style switcher by @FNDEVVE in [#1325](https://github.com/backnotprop/plannotator/pull/1325)
- fix(review): GitLab upload artifact fetching via authenticated API with hardened rewrite by @yuensunn in [#1228](https://github.com/backnotprop/plannotator/pull/1228)
- guides-show: example guide screenshot at the bottom of the landing page by @backnotprop in [#1336](https://github.com/backnotprop/plannotator/pull/1336)
- guides-show: example guide screenshot replaces the abstract figure, opens in a lightbox by @backnotprop in [#1337](https://github.com/backnotprop/plannotator/pull/1337)
- fix(review): stop the call-flow Lens closing mid-scroll and opening on drive-by hovers by @backnotprop in [#1338](https://github.com/backnotprop/plannotator/pull/1338)

## New Contributors

- @ashish921998 made their first contribution in [#1316](https://github.com/backnotprop/plannotator/pull/1316)
- @yuensunn made their first contribution in [#1228](https://github.com/backnotprop/plannotator/pull/1228)

## Contributors

Four community authors shipped code in this release, two for the first time:

- @FNDEVVE built the favicon style switcher in [#1325](https://github.com/backnotprop/plannotator/pull/1325), including restoring the classic P icon exactly as it shipped before the mascot era, and worked through a review round that added server-side icon serving so the choice applies without a flash. Their second contribution.
- @graemefolk extended Call Flow analysis to jj repositories in [#1312](https://github.com/backnotprop/plannotator/pull/1312), their third contribution to Plannotator's jj support, which they have carried since the original provider landed.
- @yuensunn fixed GitLab merge request artifacts in [#1228](https://github.com/backnotprop/plannotator/pull/1228), their first contribution, and stuck with it through a security-focused review round on the URL rewrite.
- @ashish921998 made the skill reference menu real for screen reader users in [#1316](https://github.com/backnotprop/plannotator/pull/1316), their first contribution.
- Rustan (@acewhocares on X) test-drove Call Flow in Safari and reported the Lens scroll behavior that [#1338](https://github.com/backnotprop/plannotator/pull/1338) fixes, hours after trying the feature.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.27.3...v0.27.4
