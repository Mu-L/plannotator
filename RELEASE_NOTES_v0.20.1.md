Follow [@plannotator](https://x.com/plannotator) on X for updates

---

## What's New in v0.20.1

A hotfix for Pi extension installs. If `pi install npm:@plannotator/pi-extension` failed for you today, this release fixes it.

### Pi Extension Install Failure

Fresh installs of `@plannotator/pi-extension` started failing with an npm 404. The cause was upstream: our diff renderer dependency `@pierre/diffs` published a new 1.2.x line that depends on `@pierre/theming@0.0.1`, a package that does not exist on the npm registry. Plannotator declared the dependency with a loose `^1.1.12` range, so fresh installs floated onto the broken 1.2.9 and failed before Pi could finish loading extensions. Repo builds never saw it because the lockfile pinned an older version.

The fix pins `@pierre/diffs` to exact `1.1.20` everywhere, whose dependency tree fully resolves. Update with:

```bash
pi install npm:@plannotator/pi-extension
```

- closing [#880](https://github.com/backnotprop/plannotator/issues/880)

## Install / Update

**macOS / Linux:**

```bash
curl -fsSL https://plannotator.ai/install.sh | bash
```

**Windows:**

```powershell
irm https://plannotator.ai/install.ps1 | iex
```

**Pi:** Install or update the extension:

```bash
pi install npm:@plannotator/pi-extension
```

Upgrading from before v0.20.0? Read the [v0.20.0 release notes](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0) first; that release changed how skills install.

---

## What's Changed

- fix(deps): pin @pierre/diffs to exact 1.1.20 by @backnotprop

## Community

@ramarivera reported the install failure with a complete diagnosis of the broken dependency chain, down to the exact unpublished package. @MaksimZinovev and @archidemus confirmed the failure.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.20.0...v0.20.1
