Follow [@plannotator](https://x.com/plannotator) on X for updates

---

## What's New in v0.26.7

One change, and it transforms how annotating HTML pages feels: pinpoint mode now targets any element on the page.

### Pinpoint targets what your cursor is on

Since v0.26.5, raw-HTML annotate sessions default to pinpoint input. But pinpoint could only target a fixed list of "semantic" HTML tags: headings, paragraphs, tables, sections. Real prototype and report pages are built from styled divs and spans, so hovering a small chip or an icon button selected the whole enclosing section, and some elements could not be selected at all.

Pinpoint now resolves the element actually painted under your cursor, whatever its tag. Chips, icon buttons, badges, custom cards: all individually annotatable. Elements smaller than 16px promote to their parent so you are not pixel-hunting, and containers are selected the natural way, by pointing at their padding or any spot not covered by a child. The whole interaction stays mouse-only and matches how pinpoint already feels on markdown documents. Hover labels got smarter too: a `div` with a `rowchip` class now labels as "rowchip", using its aria-label, role, or class names instead of a bare tag name.

Under the hood the hover path no longer rebuilds a document-wide element graph every frame; it is a per-event hit-test with zero document scans, which also retires the performance debt noted in the v0.26.5 pinpoint release. Anchor restoration keeps every fail-closed guarantee, and `data-testid`-style attributes (`data-test-id`, `data-cy`, `data-qa`) now count as trusted element identity for restoring annotations onto regenerated pages. One honest limit: an element with no text and no identifying attribute can be annotated in-session, but its pin does not restore on a later reopen; a pin that cannot verify its target refuses to guess.

The change went through two adversarial review rounds; the first round removed an anchoring mechanism that could have restored a pin onto the wrong sibling, in favor of failing closed.

- [#1251](https://github.com/backnotprop/plannotator/pull/1251)

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

- feat(annotate): hit-test pinpoint targeting for raw-HTML sessions by @backnotprop in [#1251](https://github.com/backnotprop/plannotator/pull/1251)

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.26.6...v0.26.7
