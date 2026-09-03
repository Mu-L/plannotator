Follow [@plannotator](https://x.com/plannotator) on X for updates

---

## What's New in v0.26.6

v0.26.6 is a rebuild-only patch: no Plannotator code changed, but every binary is now compiled with Bun 1.3.14 instead of 1.3.11.

### Env vars now work inside OS sandboxes

Binaries built with Bun 1.3.11 loaded an empty environment whenever a parent of the working directory was unreadable, which is the normal state inside OS-level sandboxes (Seatbelt on macOS, Landlock on Linux, tools like nono). Every `PLANNOTATOR_*` variable was silently ignored there: remote mode never activated, fixed ports were dropped, and no warning explained why. This was [oven-sh/bun#27802](https://github.com/oven-sh/bun/issues/27802), fixed upstream in Bun 1.3.13.

We had pinned Bun to 1.3.11 in April because 1.3.12 broke macOS binary signing outright. Before unpinning we verified both directions: a 1.3.14 build reads env vars correctly under an unreadable ancestor, and cross-compiled macOS binaries carry the same valid linker signature as the known-good releases and launch cleanly.

The release pipeline also gained two permanent guardrails: macOS binaries are now smoke-launched after every build (the April signing breakage shipped because only Linux and Windows were), and a new check runs the freshly built binary from a directory with an unreadable ancestor and asserts env vars still load.

- [#1250](https://github.com/backnotprop/plannotator/pull/1250), closing [#1249](https://github.com/backnotprop/plannotator/issues/1249) reported by @SierraJC

---

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

---

## What's Changed

- fix(ci): bump Bun build pin to 1.3.14 for sandbox env loading by @backnotprop in [#1250](https://github.com/backnotprop/plannotator/pull/1250)

## Community

@SierraJC filed [#1249](https://github.com/backnotprop/plannotator/issues/1249) with a complete diagnosis: the exact upstream Bun issue, the fix version, and a one-line repro that distinguishes "binary cannot see the variable" from "binary mishandles the variable". Reports like this make patches fast.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.26.5...v0.26.6
