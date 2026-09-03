# cnfast vs. Plannotator's `cn` — an A/B benchmark

**Question.** Should `packages/ui/lib/utils.ts` swap `twMerge(clsx(inputs))` for
[`cnfast`](https://github.com/aidenybai/cnfast)? A prior static analysis predicted the difference
would be unmeasurable at our volumes. This report tried to break that prediction with measurement.

**Verdict up front: the prediction is CONFIRMED.** cnfast is genuinely 2–5× faster at the operation
— that part of its claim reproduces cleanly here on our own recorded call corpus. But `cn` runs 698
times in a whole code-review session and 16,585 times in a heavy annotate session, so the app spends
**0.04 ms and 0.70 ms** inside it — **0.002% and 0.02%** of the renderer scripting those sessions
actually do — and the most cnfast could save is **0.03 ms and 0.38 ms**, before its slower first call
is subtracted. Across 24 full-app runs per suite it produced no coherent difference in any metric:
every code-review metric landed inside the control arm's own run-to-run spread, and the few annotate
metrics that did not were mixed in sign within the same scenario. Details, and two reasons not to
adopt it that have nothing to do with speed, below.

Harness and raw data: `BENCH_cnfast/` (see its `README.md` for layout and reproduction commands);
every measurement is in `BENCH_cnfast/results/`.

---

## 1. What each benchmark measures, and how it works

### 1.0 What is being compared

| arm | implementation |
|---|---|
| `control` | `twMerge(clsx(inputs))` — clsx 2.1.1 + tailwind-merge 3.6.0, verbatim from `packages/ui/lib/utils.ts` |
| `controlA2` | **the same function**, entered as a second arm — the A-vs-A noise floor of the protocol itself |
| `cnfast010` | `cnfast@0.1.0` — what `bun add cnfast` installs in this repo **today** |
| `cnfast020` | `cnfast@0.2.0` — npm `latest` (published 2026-09-01), fetched as a tarball |
| `noop` | same loop, same argument traversal, same sink, no merging — the harness floor |

Both cnfast versions are measured because `bun add cnfast` in this repository resolves to **0.1.0**,
not `latest`: `bunfig.toml` sets `minimumReleaseAge = 604800` (7 days) and 0.2.0 is one day old
(`error: No version matching "cnfast" found for specifier "0.2.0" (blocked by
minimum-release-age)`). 0.1.0 is what "adopt cnfast today" means here; 0.2.0 is what it would mean
after 2026-09-08. They are materially different — 46 kB vs 101 kB published bundle, 0.1.0 sniffs the
JS engine and 0.2.0 does not, 0.2.0 bounds a registry 0.1.0 leaves unbounded — so a single number
for "cnfast" would be misleading.

### 1.1 The corpus is recorded, not written

No class strings were invented. Three sources feed `BENCH_cnfast/corpus/combined.json`:

1. **Static** (`tier-a/build-corpus.ts`) — a brace-matching scan of `packages/ui` extracts the
   argument source text of **every** `cn(...)` call site: **44 call sites across 13 files**. (The 45
   `cn(` matches in the tree are these 44 plus the definition in `lib/utils.ts`.) There are **zero**
   `cn()` call sites anywhere else in the repo — `packages/editor`, `packages/review-editor`,
   `packages/guide-viewer` and every app build their class strings with plain template literals. For
   scale: `packages/ui` alone has 2,095 `className=` sites and 4,491 class-list string literals; 44
   of them pass through `cn`.

   | file | sites | | file | sites |
   |---|---|---|---|---|
   | `components/ui/dropdown-menu.tsx` | 9 | | `components/ui/tabs.tsx` | 3 |
   | `components/AgentControls.tsx` | 7 | | `components/AgentsTab.tsx` | 3 |
   | `components/ui/card.tsx` | 6 | | `components/ToolbarButtons.tsx` | 2 |
   | `components/ui/dialog.tsx` | 5 | | 5 files with 1 each | 5 |
   | `components/AnnotationPanel.tsx` | 4 | | **total** | **44** |

2. **Variant permutations** — the real `cva` configs from `button.tsx`, `badge.tsx` and
   `state-pill.tsx` are *imported and evaluated*, giving the full permutation space those components
   can produce at runtime: 7 button variants × 6 sizes, 4 badge variants, 5 pill tones, each with and
   without the `className` overrides that appear at real call sites. **204 argument lists.**

3. **Runtime** — a third build of the app (`instrumented` = control plus a recorder) is driven
   through the identical Tier B scenario scripts. It records every distinct argument shape, control's
   output for it, and the exact **order** of calls. Tier A replays that order, so the cache locality
   the benchmark sees is the cache locality the app produced.

### 1.2 Tier A — the operation itself (`tier-a/`)

One environment-agnostic engine (`harness.ts`) run unchanged under **Bun (JavaScriptCore)** and
inside a **Chromium page (V8)** — the engine the app actually runs in. Four workloads:

- **`warm-annotate`** / **`warm-review`** — replay the recorded call sequences in their recorded
  order. This is the realistic, cache-hitting regime.
- **`variant-permutations`** — all 204 cva permutations, many passes per batch: unique on the first
  pass, cache-resident afterwards, which is the state a real app settles into once every variant has
  rendered once.
- **`unique-strings`** — the cache-defeating upper bound. Every call gets a class string never seen
  before: a real corpus base string plus a unique `mt-[Npx]` arbitrary value (a real Tailwind
  arbitrary value, so it parses, has a class group, and misses both the whole-string and the
  per-token caches). Each arm draws from its **own disjoint token space**, so no arm can warm
  another's cache and every call is a genuine miss for everyone.

Plus **cold first call**, measured with one fresh process (Bun) or one fresh browser context
(Chromium) per sample — the lazy build of the Tailwind class-group structures that both
implementations pay once.

### 1.3 Tier B — real usage (`tier-b/`)

Three variants of the actual app are built through the repo's own build order
(`bun run --cwd apps/review build && bun run build:hook`), snapshotting both single-file bundles:

| variant | `packages/ui/lib/utils.ts` |
|---|---|
| `control` | unchanged |
| `cnfast` | `export { cn } from "cnfast";` — the exact form cnfast's README prescribes; identical export shape |
| `instrumented` | control plus an in-page recorder (counting + corpus capture) — **never used for timing** |

`build-variants.ts` rewrites `utils.ts`, builds, snapshots, and restores it in a `finally`.

Two suites, each driven by Playwright + CDP against a real server started from a generated fixture:

- **Code review** — `bun apps/hook/server/index.ts review` in a generated 40-file repository
  (3,697 insertions / 1,553 deletions on the branch plus 3 untracked files; 43 changed files in the
  default `since-base` view). Scenarios: cold load to interactive → scroll the whole diff (70 steps
  down, 36 back, rAF-paced) → open/close the navigation panel and annotations panel 12× → inject
  150 external review findings and scroll the populated annotations panel → a fixed 6-cycle sustained
  toggle burst (theme flip through the header Options menu, Split↔Unified, Tree↔Git status, panel
  open/close), ~12 s.
- **Annotate** — `bun apps/hook/server/index.ts annotate` on a generated 1,804-line document.
  Scenarios: cold load → inject 200 annotations → scroll document and annotation panel → a fixed
  8-cycle sustained toggle burst (theme flip, annotations panel hide/show, Contents↔Files),
  ~19 s.

Measured per scenario, via CDP `Performance.getMetrics` in the **`threadTicks`** time domain
(renderer main-thread CPU time, not wall clock): `ScriptDuration`, `TaskDuration`,
`RecalcStyleDuration`, `LayoutDuration`; plus in-page `PerformanceObserver` for long tasks and Event
Timing, and rAF timestamps for frame gaps during the sustained window.

### 1.4 Tier C — correctness (`tier-c/`)

- `parity.ts` diffs control vs both cnfast versions **byte for byte** over: the recorded runtime
  shapes, the 204 cva permutations, and a 500,000-case differential sweep whose vocabulary is
  **this repo's own** — all 3,102 distinct class tokens found in the 4,491 class-list string
  literals in `packages/ui`, recombined by a seeded PRNG into 1–12-token lists split across multiple
  arguments with falsy values, objects and nested arrays the way real call sites are written. Plus
  targeted probes for each divergence cnfast documents against tailwind-merge.
- `dom-parity.ts` drives the identical scenario against the two *shipped builds* and captures every
  element's tag + className (light **and** shadow DOM) at three points, then diffs.

---

## 2. Why the numbers are reliable — and what would invalidate them

### 2.1 Variance control

**Interleaving.** A *batch* is one full pass of a workload by one implementation. Every arm runs one
batch before any arm runs a second, and the order **inside** each batch rotates, so a thermal ramp,
a JIT tier-up, or a burst of background load cannot land preferentially on one arm. Tier B does the
same at run granularity: variants alternate run to run, and the order flips every round.

**Warmup.** Tier A discards 5 warmup batches per workload. Tier B discards run 0 of each variant.

**Run counts.** Tier A: 40 recorded batches per (workload, arm), both engines. Cold: 40 fresh
processes / 40 fresh browser contexts per arm, interleaved. Tier B: 12 recorded runs per variant per
suite (24 per suite total, 0 errors). Parity: 500,000 sweep cases.

**Statistics.** Median and interquartile range, never mean, never best-of-N. Raw per-batch and
per-run samples are kept in `results/` so anything here can be recomputed.

**Anti-DCE.** Every result is folded into a module-level sink.

### 2.2 The noise floor is measured, not assumed

Two independent floors:

- **`noop`** — the harness cost (loop, argument traversal, sink) with no merging.
- **`controlA2`** — the control function entered a *second time* as if it were a competitor. Its
  spread against `control` is the resolution of the entire A/B protocol on this machine under this
  load.

Measured A-vs-A gap (Chromium, 40 batches): `warm-annotate` 42.2 vs 42.4 ns (**0.5%**),
`warm-review` 54.4 vs 54.6 ns (0.4%), `variant-permutations` 24.0 vs 24.0 ns (0.0%),
`unique-strings` 9,075 vs 8,969 ns (1.2%). Under Bun: 132.5 vs 134.0, 185.8 vs 185.7, 170.5 vs
171.2, 12,474 vs 12,732 ns. **Any claimed effect smaller than ~1% at micro level is noise.** The
cnfast effects are 2–5×, far outside it — the micro result is real.

For Tier B the equivalent floor is the control arm's own IQR across its 12 runs, and the analyser
flags every delta that falls inside it.

### 2.3 Timer resolution — handled, not ignored

Chromium clamps `performance.now()` to ~100 µs in a page that is not cross-origin isolated. So:

- Tier A browser batches are sized (by replaying the recorded sequence many times per batch) so the
  slowest arm takes tens of milliseconds. The repeat factor changes nothing about what is measured —
  same sequence, same order, same cache behaviour.
- The cold first-call measurement, on which the whole break-even argument rests, is run on a local
  origin serving `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy:
  require-corp`. The result file records **`crossOriginIsolated: true`**, so the 5 µs timer was
  actually granted rather than assumed.

### 2.4 Isolation and build validity

- Each Tier B run: a fresh `PLANNOTATOR_DATA_DIR` under `mktemp` (removed after),
  `PLANNOTATOR_BROWSER=/usr/bin/true`, `PLANNOTATOR_AI=disabled`, `PLANNOTATOR_SHARE=disabled`,
  `PLANNOTATOR_FEEDBACK_HISTORY=0`, `PLANNOTATOR_GUIDE_HISTORY=0`, `PLANNOTATOR_ANNOTATE_HISTORY=0`,
  a fresh browser context, and a freshly started server. Nothing touched the user's real data dir.
- The first-run dialog chain is pre-dismissed with seeded cookies at their exact version values
  (`plannotator-edit-mode-announcement-seen=3`, `plannotator-guide-intro-seen=2`, …), so both
  variants open on the same screen and no dialog can steal a click. Fixtures are seeded-PRNG
  deterministic and byte-identical run to run.
- The sustained-toggle scenarios are a **fixed operation count**, so both variants perform identical
  work; elapsed time is reported rather than held constant.
- **The swap really is in the bundle.** The `cnfast` bundle differs from `control` by +2,959 bytes
  and carries cnfast-only constructs: two extra `Int32Array` occurrences (its generation-stamped
  claim tracker) and one extra `lineNumber` occurrence (its `IS_V8` engine sniff). The
  Tailwind-config marker `arbitrary..` occurs exactly once in each bundle, so exactly one merge
  implementation is present in each — tailwind-merge was tree-shaken out of the cnfast build, not
  shipped alongside it.
- CPU throttling was **off** (no `Emulation.setCPUThrottlingRate`).

### 2.5 What would invalidate these numbers

Stated plainly, strongest first:

1. **Machine load.** Measurements ran on a shared workstation (Apple M5 Max, 18 cores, macOS 26.3)
   with a 1-minute load average around 5. Interleaving neutralises *drift* between arms, and
   `threadTicks` CPU time is far more load-tolerant than wall clock, but a single-digit-percent Tier B
   delta on a loaded machine should not be read as signal — which is exactly why the analyser reports
   whether each delta falls inside the control arm's own IQR, and why none of the conclusions rest on
   a Tier B delta.
2. **Headless Chromium is not a user's browser.** Frame accounting in particular: the median rAF gap
   in the sustained window was ~8.3 ms, i.e. the headless compositor ran nearer 120 Hz than 60 Hz, so
   `framesDropped` is a *relative* comparison between arms, not an absolute claim about a user's
   display. Long-task counts and Event Timing are ordinary browser instrumentation and travel better.
3. **One machine, one OS, one browser build.** No Safari, no Windows, no low-end hardware. The
   engine-sniffing finding (§3.4) means cnfast 0.1.0's numbers here are its *best* case, and a Safari
   user would get less.
4. **The Tier B corpus is one repository and one document.** A review of a 4,000-file monorepo diff
   or an annotate session with 5,000 annotations would raise the `cn` call count. §5 gives the
   break-even call count so a maintainer can decide whether their workload could cross it, and the
   arithmetic is linear.
5. **`cn` invocation counts come from the instrumented build.** They are control + a counter, so they
   are the control arm's counts. They apply to the cnfast arm because the call *sites* are identical
   and both implementations produce byte-identical strings (§4), so React's render counts cannot
   differ — but that is an argument, not a second measurement.
6. **Script-evaluation cost is not measured.** The bundler hoists module bodies above the
   instrumentation, so the cold harness measures the first *call*, not parse/eval. The bundle delta
   is +3 kB minified (+1.9 kB gzipped), so this is very unlikely to matter, but it is unmeasured.
7. **Recorder fidelity.** The corpus recorder serialises arguments with `JSON.stringify`, which turns
   an `undefined` inside an array into `null`. Both are falsy to clsx and produce identical output,
   and no recorded shape contained one; still, the replay is of a serialised corpus, not of live
   references.

### 2.6 State of the worktree

All work was done in a throwaway worktree; the main checkout was never touched and nothing was
committed. Two tracked files were modified to make the benchmark possible and are left in place so
the harness stays runnable: `packages/ui/package.json` gained a `cnfast` dependency (needed only so
the CNFAST variant can resolve the import; the CONTROL bundle does not import it and Vite tree-shakes
it out), and `bun.lock` records it and the `playwright` dev dependency. `packages/ui/lib/utils.ts` is
byte-for-byte unchanged — `build-variants.ts` restores it in a `finally` — and `apps/hook/dist/` has
been restored to the CONTROL build. `BENCH_cnfast/` is ~138 MB, most of it the four snapshotted
single-file bundles.

---

## 3. Results

### 3.1 Micro — the operation itself

**Chromium / V8** (the engine the app runs in). 40 batches; median ns/call, `[IQR]`:

| workload | `control` | `controlA2` (A/A) | `cnfast010` | `cnfast020` | `noop` |
|---|---|---|---|---|---|
| `warm-annotate` (real order) | **42.2** `[41.9, 43.7]` | 42.4 `[42.0, 43.7]` | **19.3** `[19.2, 19.9]` | **9.0** `[8.6, 9.7]` | 6.8 |
| `warm-review` (real order) | **54.4** `[54.1, 54.8]` | 54.6 `[54.4, 55.2]` | **17.6** `[17.4, 17.7]` | **11.5** `[11.3, 11.7]` | 8.1 |
| `variant-permutations` | 24.0 `[23.8, 24.1]` | 24.0 `[23.8, 24.3]` | 12.7 `[12.5, 13.0]` | 10.0 `[9.8, 10.0]` | 5.1 |
| `unique-strings` (cache-defeating) | 9,075 `[9,022, 9,188]` | 8,969 `[8,906, 9,013]` | 2,738 `[2,700, 2,853]` | 1,581 `[1,488, 1,703]` | 25 |

**Bun / JavaScriptCore.** 40 batches; median ns/call, `[IQR]`:

| workload | `control` | `controlA2` (A/A) | `cnfast010` | `cnfast020` | `noop` |
|---|---|---|---|---|---|
| `warm-annotate` | 132.5 `[125.1, 141.6]` | 134.0 `[126.3, 143.3]` | 81.8 `[76.8, 85.8]` | 25.7 `[24.4, 27.4]` | 20.7 |
| `warm-review` | 185.8 `[185.0, 187.3]` | 185.7 `[184.7, 188.9]` | 71.4 `[71.1, 72.0]` | 31.0 `[30.8, 31.3]` | 21.6 |
| `variant-permutations` | 170.5 `[169.4, 171.7]` | 171.2 `[170.1, 172.2]` | 38.6 `[38.3, 39.1]` | 21.7 `[21.5, 22.1]` | 17.4 |
| `unique-strings` | 12,474 `[12,298, 13,077]` | 12,732 `[12,294, 13,337]` | 3,751 `[3,643, 4,095]` | 1,404 `[1,309, 1,721]` | 54 |

**cnfast's speed claim reproduces.** On our own recorded corpus in the browser it is **2.2×**
(0.1.0) to **4.7×** (0.2.0) faster warm, and **3.3×**/**5.7×** faster on the cache-defeating upper
bound. That is far outside the 0.0–1.2% A-vs-A floor. Note the floors, though: subtracting `noop`,
control's *marginal* cost on `warm-annotate` is 35.4 ns and cnfast020's is 2.2 ns — the absolute
numbers are tens of nanoseconds either way.

**Cold first call** — Chromium, cross-origin isolated (`crossOriginIsolated: true`, 5 µs timer),
40 fresh contexts per arm:

| arm | first `cn()` call | vs control | second call |
|---|---|---|---|
| `control` | **1.7475 ms** `[1.720, 1.785]` | — | ≤ 0.005 ms |
| `cnfast010` | **1.815 ms** `[1.784, 1.843]` | **+0.068 ms** | ≤ 0.005 ms |
| `cnfast020` | **2.300 ms** `[2.270, 2.331]` | **+0.553 ms** | ≤ 0.005 ms |

The IQRs do not overlap: **both cnfast versions are slower to start**, and 0.2.0 markedly so. Bun
agrees (40 fresh processes): module eval 1.625 / 1.559 / 3.012 ms and first call 2.246 / 2.150 /
2.707 ms for control / 0.1.0 / 0.2.0.

**Bundle cost** (single-file builds, control → cnfast010):

| bundle | raw | gzipped |
|---|---|---|
| `review.html` | 17,589,211 → 17,592,170 (**+2,959 B**, +0.017%) | 5,622,712 → 5,624,610 (**+1,898 B**, +0.034%) |
| `index.html` | 21,840,151 → 21,843,117 (**+2,966 B**, +0.014%) | 6,805,314 → 6,806,422 (**+1,108 B**, +0.016%) |

### 3.2 The bridge: how often `cn` actually runs

Recorded by the instrumented build during the identical scenarios (`corpus/runtime-corpus*.json`):

**Code review session — 698 `cn()` calls total, 8 distinct argument shapes.**

| scenario | `cn()` calls | scenario wall time |
|---|---|---|
| cold load to interactive | 24 | 2.9 s |
| scroll the whole 43-file diff | 282 | 2.0 s |
| navigation + annotations panel, 12 toggles | 120 | 3.8 s |
| inject 150 findings, open + scroll the panel | **14** | 3.5 s |
| sustained toggle burst (6 cycles) | 258 | 11.7 s |
| **total** | **698** | ~24 s |

**Annotate session — 16,585 `cn()` calls total, 6 distinct argument shapes.**

| scenario | `cn()` calls | scenario wall time |
|---|---|---|
| cold load of a 1,804-line document | 8 | 3.0 s |
| 200 annotations arrive and render | 808 | 2.0 s |
| scroll document + annotation panel | 2,425 | 3.0 s |
| sustained toggle burst (8 cycles) | 13,344 | 18.7 s |
| **total** | **16,585** | ~27 s |

Two facts jump out of the recorded corpus and they drive the whole verdict:

- **The distinct-shape count is 6 and 8.** Two shapes — the annotation card's base+state classes at
  `AnnotationPanel.tsx:629` and `:636` — are 8,200 calls each, 99% of the annotate corpus. tailwind-merge's
  500-entry whole-string LRU therefore hits on essentially every call. Real usage lives in the *warm*
  regime almost exclusively; the cache-defeating 9 µs column is an upper bound our app never
  approaches.
- **The expensive parts of the app do not call `cn` at all.** Rendering 43 files of diff produced 282
  calls, and *rendering 152 review findings produced 14*, because the review annotation panel is built
  from `packages/review-editor` components that use template literals, and the diff itself is
  `@pierre/diffs` rendering into a shadow root. `cn` is confined to the 13 `packages/ui` modules that
  import it.

### 3.3 Real usage — 24 full-app runs per suite

Every metric below is median `[IQR]` over 12 runs per variant, warmup discarded, variants alternating.
"inside control IQR" means the cnfast median falls within the control arm's own interquartile range.

**Code review** (`results/tier-b-summary.log`) — headline metrics:

| scenario | metric | `control` | `cnfast` | delta |
|---|---|---|---|---|
| cold | ScriptDuration (s) | 0.204 `[0.200, 0.207]` | 0.203 `[0.201, 0.205]` | −0.8% *(inside control IQR)* |
| scroll | ScriptDuration (s) | 0.528 `[0.521, 0.541]` | 0.527 `[0.522, 0.537]` | −0.3% *(inside)* |
| sidebar | ScriptDuration (s) | 0.100 `[0.095, 0.104]` | 0.099 `[0.094, 0.104]` | −0.8% *(inside)* |
| annotations | ScriptDuration (s) | 0.022 `[0.021, 0.024]` | 0.022 `[0.020, 0.023]` | −3.6% *(inside)* |
| toggles | ScriptDuration (s) | 0.996 `[0.988, 1.010]` | 1.008 `[0.993, 1.023]` | +1.2% *(inside)* |
| toggles | TaskDuration (s) | 6.791 `[6.660, 6.833]` | 6.826 `[6.654, 6.965]` | +0.5% *(inside)* |
| toggles | long tasks (count / total ms) | 24 / 3,052 | 24 / 3,056 | 0.0% / +0.1% *(inside)* |
| toggles | click latency p95 / max (ms) | 268 / 296 | 268 / 292 | 0.0% / −1.4% *(inside)* |
| toggles | frames dropped | 510 `[507, 520]` | 518 `[508, 528]` | +1.6% *(inside)* |

**Every metric in the code-review suite that had a measurable delta — 32 of 32 — landed inside the
control arm's own IQR.** (The other 8 are long-task counters that were identically zero in both arms.)

**Annotate** (`results/tier-b-annotate-summary.log`) — headline metrics:

| scenario | metric | `control` | `cnfast` | delta |
|---|---|---|---|---|
| cold | ScriptDuration (s) | 0.235 `[0.229, 0.238]` | 0.238 `[0.234, 0.239]` | +1.3% *(inside)* |
| annotations | ScriptDuration (s) | 0.036 `[0.032, 0.039]` | 0.038 `[0.034, 0.040]` | +6.2% *(inside)* |
| scroll | ScriptDuration (s) | 0.065 `[0.060, 0.068]` | 0.068 `[0.067, 0.069]` | +4.1% *(inside)* |
| toggles | ScriptDuration (s) | 2.778 `[2.743, 2.822]` | 2.737 `[2.642, 2.803]` | −1.5% |
| toggles | TaskDuration (s) | 14.215 `[14.035, 14.420]` | 13.935 `[13.867, 14.281]` | −2.0% |
| toggles | RecalcStyleDuration (s) | 5.774 `[5.712, 5.830]` | 5.891 `[5.769, 5.963]` | +2.0% |
| toggles | long tasks (count / total ms) | 41 / 8,748 | 40 / 8,783 | −2.4% / +0.4% *(inside)* |
| toggles | click latency p95 / max (ms) | 580 / 640 | 584 / 720 | +0.7% *(inside)* / +12.5% |
| toggles | frames dropped | 1,230 `[1,214, 1,242]` | 1,228 `[1,203, 1,240]` | −0.2% *(inside)* |

A handful of annotate deltas fall just outside the control IQR, but they are **mixed in sign within
the same scenario** (ScriptDuration −1.5%, RecalcStyle +2.0%, Layout +2.5%), which is the signature
of noise, not of a faster class merger. `clickMaxMs +12.5%` is a single-sample maximum and the
noisiest statistic on the sheet.

**The decisive check is the arithmetic.** In `annotate-toggles`, cnfast010's theoretical saving is
13,344 calls × (42.2 − 19.3) ns = **0.31 ms**. The *measured* ScriptDuration difference was 41 ms —
**134× larger than the effect being looked for.** The Tier B measurement cannot see cn at all; what
it saw was run-to-run variance. That is the honest reading, and it is also why no Tier B number in
this report is offered as evidence for either implementation.

Whole-session budget, using the browser micro numbers:

| session | `cn()` calls | total control ScriptDuration | time in `cn` (control) | share |
|---|---|---|---|---|
| code review | 698 | 1.850 s | **0.038 ms** | **0.0021%** |
| annotate | 16,585 | 3.114 s | **0.700 ms** | **0.022%** |

### 3.4 Two findings that are not about speed

- **cnfast is deprecated by its own author.** Its README opens: *"Check out `cn` by shadcn for an
  even faster `cn` package. cnfast will no longer be maintained in favor of `cn`. I recommend you go
  use that package instead!"* Adopting it now means adopting an explicitly unmaintained dependency.
- **cnfast 0.1.0 — the version this repo can actually install — sniffs the JS engine.** `dist/index.mjs`
  contains `const IS_V8 = (() => { const error = new Error(); return !("line" in error) &&
  !("lineNumber" in error); })()`, and takes a faster cached path only when that is true. On
  JavaScriptCore it takes the slow path, which is visible in our own data: `warm-review` is 3.1× faster
  than control in Chromium but only 2.6× in Bun. A Safari user would get the JSC path. 0.2.0 removed
  the sniff and bounded its conflict-key registry at 32,768 entries (0.1.0's never evicts) — both real
  improvements, and both unavailable to this repo for another six days.

---

## 4. Correctness and parity

`results/tier-c-parity.json`, `results/tier-c-dom-parity.json`.

**Output parity — zero divergences on anything our app produces.**

| suite | cases | `cnfast010` divergences | `cnfast020` divergences |
|---|---|---|---|
| recorded runtime shapes (review) | 8 | **0** | **0** |
| recorded runtime shapes (annotate) | 6 | **0** | **0** |
| cva permutation space | 204 | **0** | **0** |
| vocabulary sweep (3,102 of our own tokens) | **500,000** | **0** | **0** |

**Rendered-DOM parity — zero differences.** The two shipped builds were driven through the identical
review scenario and every element's tag + className was captured across light *and* shadow DOM at
three points:

| phase | elements compared | differences |
|---|---|---|
| initial review | 2,570 | **0** |
| annotations panel populated (60 findings) | 3,647 | **0** |
| dark theme + unified diff | 2,980 | **0** |

**Divergences cnfast documents, and whether our corpus hits them.** cnfast's own
`docs/upstream-tailwind-merge.md` names its behaviour differences from tailwind-merge. Each was
probed directly:

| probe | diverges? | does OUR corpus produce it? |
|---|---|---|
| **Non-breaking space (U+00A0) as separator** | **YES** — control `"px-4"`, cnfast `"px-2 px-4"` | **No.** 0 of the 4,491 class-list literals in `packages/ui` contain non-ASCII whitespace. |
| **U+2028 LINE SEPARATOR as separator** | **YES** — same shape | **No**, same scan. |
| **U+3000 IDEOGRAPHIC SPACE as separator** | **YES** — control `"bg-blue-500"`, cnfast keeps both | **No**, same scan. |
| Tab / newline separators | no | Yes — multi-line template class strings are everywhere; both split identically. |
| All-falsy arguments (`[false,false,false]`, `[false]`) | no | **Yes** — both shapes are in the recorded corpus. |
| `!important` + arbitrary values | no | Yes — arbitrary values are pervasive. |
| Numbers, nested arrays/objects, zero arguments | no | No recorded call site produces these. |
| Dynamic arbitrary variants (`data-[id=N]:`, the registry-growth concern) | no | **No** — no `cn()` call site in `packages/ui` interpolates a value into a variant. |

**Finding:** cnfast's three real divergences from tailwind-merge are all the same root cause — an
ASCII-only whitespace splitter — and **our corpus never produces the trigger**. They are a footnote
here, not a blocker. The registry-growth concern (`docs` item #6, unbounded in 0.1.0) is likewise
unreachable from our call sites, though it is the kind of thing that becomes reachable the day
someone writes `` cn(`data-[id=${id}]:flex`) ``.

---

## 5. Verdict, in the maintainer's terms

**Would real usage feel it? No — not close, and the gap is not marginal.**

The break-even calculation is the cleanest way to see it. Each swap costs a one-time slower first
call and saves a fixed amount per call thereafter (browser figures):

| version | one-time cold cost | saved per call (warm) | **calls needed to break even** |
|---|---|---|---|
| `cnfast@0.1.0` | +0.068 ms | 22.9 ns | **≈ 2,970** |
| `cnfast@0.2.0` | +0.553 ms | 33.2 ns | **≈ 16,660** |

Against that, a whole session:

| session | `cn()` calls | net effect of `cnfast@0.1.0` | net effect of `cnfast@0.2.0` |
|---|---|---|---|
| **code review** (43 files, 5.2k changed lines, 150 findings, ~24 s) | 698 | **−0.042 ms — a net LOSS** | **−0.523 ms — a net LOSS** |
| **annotate** (1,804-line doc, 200 annotations, ~27 s) | 16,585 | **+0.312 ms saved** | **≈ break-even (−0.002 ms)** |

A code-review session never reaches break-even: the app calls `cn` 698 times, four times fewer than
0.1.0 needs just to repay its own startup. The heaviest annotate session in this benchmark barely
does, and for the version that will be installable next week it lands *exactly* on the line. The best
outcome available anywhere in this app is **a third of a millisecond, once, across half a minute of
interaction** — about one fiftieth of a single 60 Hz frame. During that same annotate session the app
spent **8.7 seconds in long tasks** and **5.8 seconds in style recalculation**.

The prior static analysis is confirmed, and the reason is not that cnfast is slow — it is 2–5×
faster at the operation, on our own recorded corpus, in the engine the app runs in, well outside the
0.5% noise floor. The reason is **call volume and cache locality**: `cn` has 44 call sites in one
package, real sessions call it hundreds to low-tens-of-thousands of times, and the corpus has 6–8
distinct argument shapes, so tailwind-merge's cache is warm on essentially every call. The parts of
the app that actually cost time — the Pierre diff renderer in its shadow root, the review-editor's
own template-literal components, style recalculation — never touch `cn` at all.

**Recommendation: do not swap.** The performance case is null-to-negative for code review and
sub-frame for annotate; against it stand three real costs — a dependency its own author has
deprecated in favour of a different package, +3 kB of bundle (+1.9 kB gzipped), and three genuine
output divergences from tailwind-merge that our corpus happens not to trigger today but that a single
future class string containing a non-breaking space would.

Two things would change the answer, and both are checkable with the harness in `BENCH_cnfast/`:
a workload that pushes `cn` past ~17,000 calls per session (linear arithmetic — the harness prints
the call count), or `cn` spreading beyond `packages/ui` into the diff and review-editor render paths,
which is where this app's rendering time actually is.
