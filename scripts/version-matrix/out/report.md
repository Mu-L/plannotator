# Plannotator version-matrix report

Generated: 2026-08-06T07:49:11.109Z
Versions: v0.24.2, v0.25.1, v0.26.0, v0.26.1, dev

All captures are the **since-base** view of the same fixture repo
(feature/spaceship: committed dir rename etoro/ -> spaceship/ +
file rename Card.tsx -> Panel.tsx, uncommitted edits, whitespace-only
change, unstaged deletion, mode-only change, modified ~6MB text file,
untracked files). Cells marked ⚠ disagree across versions.

## Version × metric matrix

| metric | v0.24.2 | v0.25.1 | v0.26.0 | v0.26.1 | dev |
|---|---|---|---|---|---|
| initial diffType | since-base | since-base | since-base | since-base | since-base |
| served diffType | since-base | since-base | since-base | since-base | since-base |
| base | main | main | main | main | main |
| diff error | none | none | none | none | none |
| total + ⚠ | 35 | 35 | 26 | 26 | 34 |
| total - ⚠ | 22 | 22 | 20 | 20 | 22 |
| file count | 13 | 13 | 13 | 13 | 13 |
| renames in patch | packages/universal/src/components/etoro/Button.tsx -> packages/universal/src/components/spaceship/Button.tsx; packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx; packages/universal/src/components/etoro/Chart.tsx -> packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/etoro/theme.ts -> packages/universal/src/components/spaceship/theme.ts | packages/universal/src/components/etoro/Button.tsx -> packages/universal/src/components/spaceship/Button.tsx; packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx; packages/universal/src/components/etoro/Chart.tsx -> packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/etoro/theme.ts -> packages/universal/src/components/spaceship/theme.ts | packages/universal/src/components/etoro/Button.tsx -> packages/universal/src/components/spaceship/Button.tsx; packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx; packages/universal/src/components/etoro/Chart.tsx -> packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/etoro/theme.ts -> packages/universal/src/components/spaceship/theme.ts | packages/universal/src/components/etoro/Button.tsx -> packages/universal/src/components/spaceship/Button.tsx; packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx; packages/universal/src/components/etoro/Chart.tsx -> packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/etoro/theme.ts -> packages/universal/src/components/spaceship/theme.ts | packages/universal/src/components/etoro/Button.tsx -> packages/universal/src/components/spaceship/Button.tsx; packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx; packages/universal/src/components/etoro/Chart.tsx -> packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/etoro/theme.ts -> packages/universal/src/components/spaceship/theme.ts |
| renamed-file (Panel.tsx) handling ⚠ | R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h2 +8/-2 | R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h2 +8/-2 | R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h0 +0/-0 | R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h0 +0/-0 | R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h2 +8/-2 |
| deletions | apps/web/src/legacy.ts -6 | apps/web/src/legacy.ts -6 | apps/web/src/legacy.ts -6 | apps/web/src/legacy.ts -6 | apps/web/src/legacy.ts -6 |
| empty-hunk files | packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/spaceship/theme.ts | packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/spaceship/theme.ts | packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/spaceship/theme.ts | packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/spaceship/theme.ts | packages/universal/src/components/spaceship/Chart.tsx; packages/universal/src/components/spaceship/theme.ts |
| mode-only files | tools/build.sh | tools/build.sh | tools/build.sh | tools/build.sh | tools/build.sh |
| binary-stub files ⚠ | none | none | bigassets/metrics-6mb.txt; packages/universal/src/components/spaceship/Panel.tsx | bigassets/metrics-6mb.txt; packages/universal/src/components/spaceship/Panel.tsx | bigassets/metrics-6mb.txt |
| big-file representation ⚠ | M h1 +1/-0 | M h1 +1/-0 | binary stub (M) | binary stub (M) | binary stub (M) |
| sections partition | committed:5 changes:6 untracked:2 | committed:5 changes:6 untracked:2 | committed:5 changes:6 untracked:2 | committed:5 changes:6 untracked:2 | committed:5 changes:6 untracked:2 |
| sections base | main | main | main | main | main |
| /api/commits | 4 commits (base main) | 4 commits (base main) | 4 commits (base main) | 4 commits (base main) | 4 commits (base main) |
| probe normal (index.ts) | 200 old=242ch new=292ch | 200 old=242ch new=292ch | 200 old=242ch new=292ch | 200 old=242ch new=292ch | 200 old=242ch new=292ch |
| probe renamed (Panel.tsx oldPath=Card.tsx) ⚠ | 200 old=279ch new=413ch | 200 old=279ch new=413ch | 200 keys: oldContent,newContent | 200 keys: oldContent,newContent | 200 old=279ch new=413ch |
| probe big (6MB) ⚠ | 200 old=6800000ch new=6800068ch | 200 keys: oldContent,newContent | 200 keys: oldContent,newContent | 200 keys: oldContent,newContent | 200 keys: oldContent,newContent |

## Per-file matrix (status / hunks / +adds/-dels)

| file | v0.24.2 | v0.25.1 | v0.26.0 | v0.26.1 | dev | git truth |
|---|---|---|---|---|---|---|
| `apps/mobile/src/App.tsx` | M h1 +1/-1 | M h1 +1/-1 | M h1 +1/-1 | M h1 +1/-1 | M h1 +1/-1 | M +1/-1 |
| `apps/mobile/src/screens/Home.tsx` | M h1 +7/-7 | M h1 +7/-7 | M h1 +7/-7 | M h1 +7/-7 | M h1 +7/-7 | M +7/-7 |
| `apps/web/src/index.ts` | M h1 +3/-1 | M h1 +3/-1 | M h1 +3/-1 | M h1 +3/-1 | M h1 +3/-1 | M +3/-1 |
| `apps/web/src/legacy.ts` | D h1 +0/-6 | D h1 +0/-6 | D h1 +0/-6 | D h1 +0/-6 | D h1 +0/-6 | D +0/-6 |
| `apps/web/src/newfeature.ts` | A h1 +3/-0 | A h1 +3/-0 | A h1 +3/-0 | A h1 +3/-0 | A h1 +3/-0 | untracked (A) |
| `bigassets/metrics-6mb.txt` ⚠ | M h1 +1/-0 | M h1 +1/-0 | M(bin) h0 +0/-0 | M(bin) h0 +0/-0 | M(bin) h0 +0/-0 | M +1/-0 |
| `docs/drafts/scratch.md` | A h1 +7/-0 | A h1 +7/-0 | A h1 +7/-0 | A h1 +7/-0 | A h1 +7/-0 | untracked (A) |
| `packages/universal/src/components/etoro/Button.tsx -> packages/universal/src/components/spaceship/Button.tsx` | R h1 +1/-1 | R h1 +1/-1 | R h1 +1/-1 | R h1 +1/-1 | R h1 +1/-1 | R067 |
| `packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx` ⚠ | R h2 +8/-2 | R h2 +8/-2 | R(bin) h0 +0/-0 | R(bin) h0 +0/-0 | R h2 +8/-2 | R050 |
| `packages/universal/src/components/etoro/Chart.tsx -> packages/universal/src/components/spaceship/Chart.tsx` | R h0 +0/-0 | R h0 +0/-0 | R h0 +0/-0 | R h0 +0/-0 | R h0 +0/-0 | R100 |
| `packages/universal/src/components/etoro/theme.ts -> packages/universal/src/components/spaceship/theme.ts` | R h0 +0/-0 | R h0 +0/-0 | R h0 +0/-0 | R h0 +0/-0 | R h0 +0/-0 | R100 |
| `packages/universal/src/index.ts` | M h1 +4/-4 | M h1 +4/-4 | M h1 +4/-4 | M h1 +4/-4 | M h1 +4/-4 | M +4/-4 |
| `tools/build.sh` | M h0 +0/-0 | M h0 +0/-0 | M h0 +0/-0 | M h0 +0/-0 | M h0 +0/-0 | M +0/-0 |

## Disagreements

### total +

- **v0.24.2**: 35
- **v0.25.1**: 35
- **v0.26.0**: 26
- **v0.26.1**: 26
- **dev**: 34
- **git truth**: tracked +25 (since-base incl. untracked: +35)

### total -

- **v0.24.2**: 22
- **v0.25.1**: 22
- **v0.26.0**: 20
- **v0.26.1**: 20
- **dev**: 22
- **git truth**: -22

### renamed-file (Panel.tsx) handling

- **v0.24.2**: R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h2 +8/-2
- **v0.25.1**: R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h2 +8/-2
- **v0.26.0**: R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h0 +0/-0
- **v0.26.1**: R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h0 +0/-0
- **dev**: R packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx h2 +8/-2

### binary-stub files

- **v0.24.2**: none
- **v0.25.1**: none
- **v0.26.0**: bigassets/metrics-6mb.txt; packages/universal/src/components/spaceship/Panel.tsx
- **v0.26.1**: bigassets/metrics-6mb.txt; packages/universal/src/components/spaceship/Panel.tsx
- **dev**: bigassets/metrics-6mb.txt

### big-file representation

- **v0.24.2**: M h1 +1/-0
- **v0.25.1**: M h1 +1/-0
- **v0.26.0**: binary stub (M)
- **v0.26.1**: binary stub (M)
- **dev**: binary stub (M)

### probe renamed (Panel.tsx oldPath=Card.tsx)

- **v0.24.2**: 200 old=279ch new=413ch
- **v0.25.1**: 200 old=279ch new=413ch
- **v0.26.0**: 200 keys: oldContent,newContent
- **v0.26.1**: 200 keys: oldContent,newContent
- **dev**: 200 old=279ch new=413ch

### probe big (6MB)

- **v0.24.2**: 200 old=6800000ch new=6800068ch
- **v0.25.1**: 200 keys: oldContent,newContent
- **v0.26.0**: 200 keys: oldContent,newContent
- **v0.26.1**: 200 keys: oldContent,newContent
- **dev**: 200 keys: oldContent,newContent

### Per-file deltas

- `bigassets/metrics-6mb.txt`: v0.24.2=M h1 +1/-0; v0.25.1=M h1 +1/-0; v0.26.0=M(bin) h0 +0/-0; v0.26.1=M(bin) h0 +0/-0; dev=M(bin) h0 +0/-0
- `packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx`: v0.24.2=R h2 +8/-2; v0.25.1=R h2 +8/-2; v0.26.0=R(bin) h0 +0/-0; v0.26.1=R(bin) h0 +0/-0; dev=R h2 +8/-2

## Git ground truth

- merge-base(main, HEAD): `825e19881d70a197aea8fe52f946f2b653321e60`
- tracked totals (git diff -M --numstat, no size threshold): +25/-22 across 11 files
- untracked files: apps/web/src/newfeature.ts, docs/drafts/scratch.md
- since-base equivalent totals (tracked + untracked lines): +35/-22
- name-status (-M): M apps/mobile/src/App.tsx; M apps/mobile/src/screens/Home.tsx; M apps/web/src/index.ts; D apps/web/src/legacy.ts; M bigassets/metrics-6mb.txt; R067 packages/universal/src/components/etoro/Button.tsx -> packages/universal/src/components/spaceship/Button.tsx; R100 packages/universal/src/components/etoro/Chart.tsx -> packages/universal/src/components/spaceship/Chart.tsx; R050 packages/universal/src/components/etoro/Card.tsx -> packages/universal/src/components/spaceship/Panel.tsx; R100 packages/universal/src/components/etoro/theme.ts -> packages/universal/src/components/spaceship/theme.ts; M packages/universal/src/index.ts; M tools/build.sh

Note: current Plannotator runs git with `core.bigFileThreshold=5MB`
(MAX_REVIEW_FILE_CONTENT_BYTES), so on versions enforcing that bound the
~6MB file appears as a binary stub even though raw git (default threshold
512MB) diffs it as text. Versions predating the bound show a text diff.

