#!/usr/bin/env bash
# fixture.sh — deterministically build the "complicated repo" fixture used by
# the Plannotator version-matrix harness.
#
# Usage: fixture.sh <target-dir>
#
# Idempotent: if <target-dir> already holds a fixture with the same
# FIXTURE_REV, it is left untouched. A fixture with a different rev is
# rebuilt. A non-empty directory that is NOT a harness fixture is refused.
#
# The fixture is a pnpm-style monorepo on branch feature/spaceship with:
#   - COMMITTED on the branch: directory rename
#     packages/universal/src/components/etoro/ -> spaceship/ plus a file
#     rename (Card.tsx -> Panel.tsx) with small edits.
#   - UNCOMMITTED: edits on a renamed file, on normal files, and a
#     whitespace-only change.
#   - untracked new files, an unstaged file deletion, a mode-only change.
#   - a ~6MB tracked text file with an uncommitted modification (exceeds
#     Plannotator's MAX_REVIEW_FILE_CONTENT_BYTES = 5MB).
#   - .gitattributes marking the big file with the `diff` attribute.
#   - a language-less code fence in docs plus normal code files.
set -euo pipefail

FIXTURE_REV="pvm-fixture-r3"

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "usage: fixture.sh <target-dir>" >&2
  exit 2
fi

MARKER_REL=".git/plannotator-fixture-rev"

if [ -e "$TARGET" ]; then
  if [ -f "$TARGET/$MARKER_REL" ]; then
    if [ "$(cat "$TARGET/$MARKER_REL")" = "$FIXTURE_REV" ]; then
      echo "fixture: $TARGET already at $FIXTURE_REV (unchanged)"
      exit 0
    fi
    echo "fixture: rebuilding $TARGET (rev changed)"
    rm -rf "$TARGET"
  elif [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    echo "fixture: refusing to overwrite non-fixture directory: $TARGET" >&2
    exit 2
  else
    rm -rf "$TARGET"
  fi
fi

umask 022
mkdir -p "$TARGET"
cd "$TARGET"

# Deterministic git environment.
export GIT_AUTHOR_NAME="Fixture Bot"
export GIT_AUTHOR_EMAIL="fixture@plannotator.test"
export GIT_COMMITTER_NAME="Fixture Bot"
export GIT_COMMITTER_EMAIL="fixture@plannotator.test"
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null

git init -q -b main
git config core.autocrlf false
git config core.fileMode true
git config user.name "$GIT_AUTHOR_NAME"
git config user.email "$GIT_AUTHOR_EMAIL"

commit() {
  # commit <date-iso> <message>
  GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -q -m "$2"
}

# ---------------------------------------------------------------- main tree
mkdir -p apps/web/src apps/mobile/src/screens \
  packages/universal/src/components/etoro docs tools bigassets

cat > package.json <<'EOF'
{
  "name": "acme-monorepo",
  "private": true,
  "scripts": { "build": "pnpm -r build", "test": "pnpm -r test" }
}
EOF

cat > pnpm-workspace.yaml <<'EOF'
packages:
  - "apps/*"
  - "packages/*"
EOF

cat > pnpm-lock.yaml <<'EOF'
lockfileVersion: '9.0'
settings:
  autoInstallPeers: true
importers:
  .: {}
  apps/web: {}
  apps/mobile: {}
  packages/universal: {}
EOF

cat > .gitattributes <<'EOF'
# Force the big metrics file to be treated as diffable text.
bigassets/metrics-6mb.txt diff
EOF

cat > apps/web/package.json <<'EOF'
{ "name": "@acme/web", "version": "1.0.0", "dependencies": { "@acme/universal": "workspace:*" } }
EOF

cat > apps/web/src/index.ts <<'EOF'
import { renderApp } from "./util";
import { Button } from "@acme/universal";

export function main(): void {
  const root = document.getElementById("root");
  if (!root) throw new Error("missing root");
  renderApp(root, Button);
}

main();
EOF

cat > apps/web/src/util.ts <<'EOF'
export function renderApp(root: HTMLElement, component: unknown): void {
  root.textContent = String(component);
}

export function debounce<T extends (...args: never[]) => void>(fn: T, ms: number): T {
  let t: ReturnType<typeof setTimeout> | undefined;
  return ((...args: never[]) => {
    if (t) clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  }) as T;
}
EOF

cat > apps/web/src/legacy.ts <<'EOF'
// Legacy bootstrap kept for reference; scheduled for deletion.
export function legacyBoot(): void {
  console.log("legacy boot path");
}

export const LEGACY_FLAG = true;
EOF

cat > apps/web/README.md <<'EOF'
# @acme/web

Web app of the acme monorepo.
EOF

cat > apps/mobile/package.json <<'EOF'
{ "name": "@acme/mobile", "version": "1.0.0", "dependencies": { "@acme/universal": "workspace:*" } }
EOF

cat > apps/mobile/src/App.tsx <<'EOF'
import { HomeScreen } from "./screens/Home";

export function App() {
  return <HomeScreen title="acme" />;
}
EOF

cat > apps/mobile/src/screens/Home.tsx <<'EOF'
export interface HomeProps {
  title: string;
}

export function HomeScreen(props: HomeProps) {
  return (
    <div>
      <h1>{props.title}</h1>
      <p>welcome home</p>
    </div>
  );
}
EOF

cat > packages/universal/package.json <<'EOF'
{ "name": "@acme/universal", "version": "1.0.0", "main": "src/index.ts" }
EOF

cat > packages/universal/src/index.ts <<'EOF'
export { Button } from "./components/etoro/Button";
export { Card } from "./components/etoro/Card";
export { Chart } from "./components/etoro/Chart";
export { theme } from "./components/etoro/theme";
EOF

cat > packages/universal/src/components/etoro/Button.tsx <<'EOF'
import { theme } from "./theme";

export interface ButtonProps {
  label: string;
  onPress: () => void;
}

export function Button(props: ButtonProps) {
  return (
    <button style={{ color: theme.primary }} onClick={props.onPress}>
      {props.label}
    </button>
  );
}
EOF

cat > packages/universal/src/components/etoro/Card.tsx <<'EOF'
import { theme } from "./theme";

export interface CardProps {
  heading: string;
  body: string;
}

export function Card(props: CardProps) {
  return (
    <section style={{ border: theme.border }}>
      <h2>{props.heading}</h2>
      <p>{props.body}</p>
    </section>
  );
}
EOF

cat > packages/universal/src/components/etoro/Chart.tsx <<'EOF'
export interface ChartProps {
  points: number[];
}

export function Chart(props: ChartProps) {
  const max = Math.max(...props.points, 1);
  return (
    <svg viewBox="0 0 100 40">
      {props.points.map((p, i) => (
        <rect key={i} x={i * 10} y={40 - (p / max) * 40} width={8} height={(p / max) * 40} />
      ))}
    </svg>
  );
}
EOF

cat > packages/universal/src/components/etoro/theme.ts <<'EOF'
export const theme = {
  primary: "#3fb950",
  border: "1px solid #30363d",
  radius: 6,
};
EOF

cat > docs/notes.md <<'EOF'
# Engineering notes

A code fence with no language tag:

```
plain fence content
second line of plain fence
```

And a typed one:

```ts
export const x: number = 1;
```
EOF

cat > tools/build.sh <<'EOF'
#!/bin/sh
# Build helper (mode change is applied later, uncommitted).
echo "building..."
EOF
chmod 644 tools/build.sh

# ~6MB deterministic text file (100k lines x ~63 bytes).
awk 'BEGIN {
  for (i = 1; i <= 100000; i++) {
    printf "metric line %08d value=%012d checksum=%08x padpadpad\n", i, i * 37, i * 2654435761 % 4294967296;
  }
}' > bigassets/metrics-6mb.txt

git add -A
commit "2026-01-05T10:00:00Z" "chore: scaffold acme monorepo"

cat >> docs/notes.md <<'EOF'

## Later addition

Committed on main after the scaffold.
EOF
git add docs/notes.md
commit "2026-01-06T10:00:00Z" "docs: expand engineering notes"

# ------------------------------------------------- feature branch (committed)
git checkout -q -b feature/spaceship

# Directory rename etoro -> spaceship, committed.
git mv packages/universal/src/components/etoro packages/universal/src/components/spaceship
# File rename with a small edit: Card.tsx -> Panel.tsx.
git mv packages/universal/src/components/spaceship/Card.tsx packages/universal/src/components/spaceship/Panel.tsx
# Small edits on renamed files (keep similarity high so rename detection holds).
perl -pi -e 's/export function Card\(/export function Panel(/; s/interface CardProps/interface PanelProps/; s/props: CardProps/props: PanelProps/' \
  packages/universal/src/components/spaceship/Panel.tsx
printf '\nexport const PANEL_KIND = "spaceship";\n' >> packages/universal/src/components/spaceship/Panel.tsx
perl -pi -e 's/color: theme\.primary/color: theme.primary, borderRadius: theme.radius/' \
  packages/universal/src/components/spaceship/Button.tsx
cat > packages/universal/src/index.ts <<'EOF'
export { Button } from "./components/spaceship/Button";
export { Panel } from "./components/spaceship/Panel";
export { Chart } from "./components/spaceship/Chart";
export { theme } from "./components/spaceship/theme";
EOF
git add -A
commit "2026-01-07T09:00:00Z" "refactor(universal): rename etoro components to spaceship"

perl -pi -e 's/title="acme"/title="acme spaceship"/' apps/mobile/src/App.tsx
git add apps/mobile/src/App.tsx
commit "2026-01-07T11:30:00Z" "feat(mobile): spaceship branding in App"

# ------------------------------------------------ working tree (uncommitted)
# 1. Edit a renamed file.
printf '\nexport function panelId(props: PanelProps): string {\n  return "panel:" + props.heading;\n}\n' \
  >> packages/universal/src/components/spaceship/Panel.tsx

# 2. Edit a normal (never-renamed) file.
perl -pi -e 's/throw new Error\("missing root"\)/throw new Error("root element not found")/' apps/web/src/index.ts
printf '\nexport const BUILD_CHANNEL = "canary";\n' >> apps/web/src/index.ts

# 3. Whitespace-only change (re-indent 2 -> 4 spaces, add trailing spaces).
perl -0pi -e 's/^  /    /mg' apps/mobile/src/screens/Home.tsx
perl -pi -e 's/welcome home<\/p>/welcome home<\/p>  /' apps/mobile/src/screens/Home.tsx

# 4. Unstaged file deletion.
rm apps/web/src/legacy.ts

# 5. Mode-only change.
chmod 755 tools/build.sh

# 6. Modify the big file (stays ~6MB, over the 5MB review bound).
printf 'metric line APPENDED value=000000000000 checksum=deadbeef padpadpad\n' >> bigassets/metrics-6mb.txt

# 7. Untracked new files.
cat > apps/web/src/newfeature.ts <<'EOF'
export function newFeature(): string {
  return "untracked new feature";
}
EOF
mkdir -p docs/drafts
cat > docs/drafts/scratch.md <<'EOF'
# Scratch (untracked)

An untracked markdown file with a language-less fence:

```
untracked fence body
```
EOF

echo "$FIXTURE_REV" > "$MARKER_REL"
echo "fixture: built $TARGET at $FIXTURE_REV (branch $(git rev-parse --abbrev-ref HEAD), HEAD $(git rev-parse --short HEAD))"
