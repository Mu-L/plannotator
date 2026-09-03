#!/usr/bin/env node
// compare.mjs — normalize per-version captures from run.sh and emit a
// cross-version comparison report (out/report.md) highlighting where
// versions disagree with each other and with raw git ground truth.
//
// Usage: node compare.mjs [--out <out-dir>]
//   out-dir default: <script-dir>/out
//
// Reads:  out/<version>/{diff.json,diff_initial.json,stats.json,commits.json,
//                        probe_*.json,meta.json}
//         out/_git-truth/{numstat.txt,name-status.txt,status.txt,merge-base.txt,
//                         untracked-lines.txt}
// Writes: out/report.md, out/report.json

import { readFileSync, readdirSync, writeFileSync, existsSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { parsePatch } from "./lib/parse-patch.mjs";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
let OUT_DIR = join(SCRIPT_DIR, "out");
{
  const args = process.argv.slice(2);
  const i = args.indexOf("--out");
  if (i !== -1 && args[i + 1]) OUT_DIR = args[i + 1];
}

const BIG_FILE = "bigassets/metrics-6mb.txt";
const RENAMED_NEW = "packages/universal/src/components/spaceship/Panel.tsx";
const RENAMED_OLD = "packages/universal/src/components/etoro/Card.tsx";

// ---------------------------------------------------------------- helpers
function readJSON(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

function readText(path) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return null;
  }
}

// Normalization: values that legitimately differ per run (ports, snapshot
// ids, timestamps, temp paths) must not create false disagreements. We only
// compare derived metrics, and we scrub sandbox paths out of any strings we
// show verbatim.
function scrub(s) {
  if (typeof s !== "string") return s;
  return s
    .replace(/\/(?:private\/)?(?:var|tmp)\/[^\s"']*pvm-[^\s"']*/g, "<sandbox>")
    .replace(/127\.0\.0\.1:\d+/g, "127.0.0.1:<port>")
    .replace(/localhost:\d+/g, "localhost:<port>");
}

// ---------------------------------------------------------------- versions
const versionDirs = readdirSync(OUT_DIR).filter((d) => {
  if (d.startsWith("_") || d.startsWith(".")) return false;
  try {
    return statSync(join(OUT_DIR, d)).isDirectory();
  } catch {
    return false;
  }
});

// Sort semver-ish, dev last.
versionDirs.sort((a, b) => {
  if (a === "dev") return 1;
  if (b === "dev") return -1;
  const pa = a.replace(/^v/, "").split(".").map(Number);
  const pb = b.replace(/^v/, "").split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] ?? 0) !== (pb[i] ?? 0)) return (pa[i] ?? 0) - (pb[i] ?? 0);
  }
  return 0;
});

if (versionDirs.length === 0) {
  console.error(`compare: no version capture dirs in ${OUT_DIR}`);
  process.exit(1);
}

function probeSummary(dir, name) {
  const path = join(dir, `${name}.json`);
  if (!existsSync(path)) return "not captured";
  const body = readJSON(path);
  if (body == null) {
    const raw = readText(path);
    return raw && raw.trim() ? `non-JSON (${raw.trim().slice(0, 40)})` : "empty body";
  }
  if (body.error) return `error: ${scrub(String(body.error))}`;
  const oldLen = typeof body.oldContent === "string" ? body.oldContent.length : null;
  const newLen = typeof body.newContent === "string" ? body.newContent.length : null;
  if (oldLen === null && newLen === null) return `keys: ${Object.keys(body).join(",") || "(none)"}`;
  return `old=${oldLen === null ? "null" : oldLen}ch new=${newLen === null ? "null" : newLen}ch`;
}

function summarizeVersion(version) {
  const dir = join(OUT_DIR, version);
  const meta = readJSON(join(dir, "meta.json")) ?? {};
  const diff = readJSON(join(dir, "diff.json"));
  const diffInitial = readJSON(join(dir, "diff_initial.json"));
  let stats = readJSON(join(dir, "stats.json"));
  if (!stats && diff?.rawPatch != null) stats = parsePatch(diff.rawPatch);

  const httpMeta = meta.http ?? {};
  const s = {
    version,
    initialDiffType: diffInitial?.diffType ?? "n/a",
    servedDiffType: diff?.diffType ?? "n/a",
    base: diff?.base ?? "n/a",
    error: diff?.error ? scrub(String(diff.error)) : null,
    totals: stats?.totals ?? null,
    files: stats?.files ?? [],
    renames: stats?.renames ?? [],
    emptyHunkFiles: stats?.emptyHunkFiles ?? [],
    modeOnlyFiles: stats?.modeOnlyFiles ?? [],
    binaryFiles: stats?.binaryFiles ?? [],
  };

  // Per-file status map (path -> compact descriptor).
  s.perFile = {};
  for (const f of s.files) {
    const key = f.status === "R" ? `${f.renameFrom ?? f.oldPath} -> ${f.renameTo ?? f.newPath}` : f.path;
    s.perFile[key] = `${f.status}${f.binary ? "(bin)" : ""} h${f.hunks} +${f.adds}/-${f.dels}`;
  }

  // Big-file representation.
  const bigEntries = s.files.filter(
    (f) => f.path === BIG_FILE || f.oldPath === BIG_FILE || f.newPath === BIG_FILE,
  );
  if (bigEntries.length === 0) {
    s.bigFile = diff ? "ABSENT from patch" : "n/a";
  } else {
    s.bigFile = bigEntries
      .map((f) => (f.binary ? `binary stub (${f.status})` : `${f.status} h${f.hunks} +${f.adds}/-${f.dels}`))
      .join("; ");
  }

  // Rename handling for the committed dir/file rename.
  const renamedAsR = s.files.find(
    (f) => f.status === "R" && (f.renameTo === RENAMED_NEW || f.newPath === RENAMED_NEW),
  );
  const renamedAsOther = s.files.filter(
    (f) => f.status !== "R" && (f.path === RENAMED_NEW || f.path === RENAMED_OLD),
  );
  if (renamedAsR) {
    s.renamedFileHandling = `R ${renamedAsR.renameFrom ?? renamedAsR.oldPath} -> ${renamedAsR.renameTo ?? renamedAsR.newPath} h${renamedAsR.hunks} +${renamedAsR.adds}/-${renamedAsR.dels}`;
  } else if (renamedAsOther.length > 0) {
    s.renamedFileHandling = renamedAsOther.map((f) => `${f.status} ${f.path} h${f.hunks} +${f.adds}/-${f.dels}`).join("; ");
  } else {
    s.renamedFileHandling = diff ? "ABSENT from patch" : "n/a";
  }

  // Deletions.
  s.deletions = s.files.filter((f) => f.status === "D").map((f) => `${f.oldPath ?? f.path} -${f.dels}`);

  // Sections sidecar.
  const sections = diff?.sections;
  if (sections?.files) {
    const groups = { committed: [], changes: [], untracked: [] };
    for (const [p, e] of Object.entries(sections.files)) {
      (groups[e.group] ?? (groups[e.group] = [])).push(p);
    }
    for (const g of Object.keys(groups)) groups[g].sort();
    s.sections = groups;
    s.sectionsBase = sections.base ?? null;
  } else {
    s.sections = null;
    s.sectionsBase = null;
  }

  // Commits endpoint.
  const commitsStatus = httpMeta.commits?.status ?? "n/a";
  const commits = readJSON(join(dir, "commits.json"));
  if (commitsStatus === "200" && commits?.commits) {
    s.commits = `${commits.commits.length} commits (base ${commits.base ?? "?"})`;
    s.commitSubjects = commits.commits.map((c) => c.subject ?? c.message ?? "?");
  } else {
    s.commits = `n/a (HTTP ${commitsStatus})`;
    s.commitSubjects = null;
  }

  // Probes.
  s.probeNormal = `${httpMeta.probe_normal?.status ?? "?"} ${probeSummary(dir, "probe_normal")}`;
  s.probeRenamed = `${httpMeta.probe_renamed?.status ?? "?"} ${probeSummary(dir, "probe_renamed")}`;
  s.probeBig = `${httpMeta.probe_big?.status ?? "?"} ${probeSummary(dir, "probe_big")}`;

  return s;
}

const summaries = versionDirs.map(summarizeVersion);

// ---------------------------------------------------------------- git truth
const truthDir = join(OUT_DIR, "_git-truth");
const truth = { available: existsSync(truthDir) };
if (truth.available) {
  truth.mergeBase = (readText(join(truthDir, "merge-base.txt")) ?? "").trim();
  const numstat = readText(join(truthDir, "numstat.txt")) ?? "";
  truth.numstat = {};
  let tAdds = 0;
  let tDels = 0;
  for (const line of numstat.split("\n")) {
    if (!line.trim()) continue;
    const [a, d, ...rest] = line.split("\t");
    const p = rest.join("\t");
    truth.numstat[p] = { adds: a === "-" ? null : Number(a), dels: d === "-" ? null : Number(d) };
    if (a !== "-") tAdds += Number(a);
    if (d !== "-") tDels += Number(d);
  }
  const nameStatus = readText(join(truthDir, "name-status.txt")) ?? "";
  truth.status = {};
  for (const line of nameStatus.split("\n")) {
    if (!line.trim()) continue;
    const parts = line.split("\t");
    const code = parts[0];
    if (code.startsWith("R") || code.startsWith("C")) {
      truth.status[`${parts[1]} -> ${parts[2]}`] = code;
    } else {
      truth.status[parts[1]] = code;
    }
  }
  truth.untracked = [];
  let uAdds = 0;
  const untrackedLines = readText(join(truthDir, "untracked-lines.txt")) ?? "";
  for (const line of untrackedLines.split("\n")) {
    const m = line.trim().match(/^(\d+)\s+(.*)$/);
    if (m) {
      truth.untracked.push(m[2]);
      uAdds += Number(m[1]);
    }
  }
  truth.trackedTotals = { adds: tAdds, dels: tDels };
  truth.sinceBaseTotals = { adds: tAdds + uAdds, dels: tDels, files: Object.keys(truth.numstat).length + truth.untracked.length };
}

// ---------------------------------------------------------------- matrix
const metrics = [
  ["initial diffType", (s) => s.initialDiffType],
  ["served diffType", (s) => s.servedDiffType],
  ["base", (s) => s.base],
  ["diff error", (s) => s.error ?? "none"],
  ["total +", (s) => (s.totals ? String(s.totals.adds) : "n/a")],
  ["total -", (s) => (s.totals ? String(s.totals.dels) : "n/a")],
  ["file count", (s) => (s.totals ? String(s.totals.files) : "n/a")],
  ["renames in patch", (s) => (s.renames.length ? s.renames.slice().sort().join("; ") : "none")],
  ["renamed-file (Panel.tsx) handling", (s) => s.renamedFileHandling],
  ["deletions", (s) => (s.deletions.length ? s.deletions.slice().sort().join("; ") : "none")],
  ["empty-hunk files", (s) => (s.emptyHunkFiles.length ? s.emptyHunkFiles.slice().sort().join("; ") : "none")],
  ["mode-only files", (s) => (s.modeOnlyFiles.length ? s.modeOnlyFiles.slice().sort().join("; ") : "none")],
  ["binary-stub files", (s) => (s.binaryFiles.length ? s.binaryFiles.slice().sort().join("; ") : "none")],
  ["big-file representation", (s) => s.bigFile],
  [
    "sections partition",
    (s) =>
      s.sections
        ? `committed:${s.sections.committed.length} changes:${s.sections.changes.length} untracked:${s.sections.untracked.length}`
        : "n/a",
  ],
  ["sections base", (s) => s.sectionsBase ?? "n/a"],
  ["/api/commits", (s) => s.commits],
  ["probe normal (index.ts)", (s) => s.probeNormal],
  ["probe renamed (Panel.tsx oldPath=Card.tsx)", (s) => s.probeRenamed],
  ["probe big (6MB)", (s) => s.probeBig],
];

const rows = metrics.map(([label, fn]) => {
  const values = summaries.map((s) => fn(s));
  const disagree = new Set(values).size > 1;
  return { label, values, disagree };
});

// Per-file disagreement details.
const allFileKeys = new Set();
for (const s of summaries) for (const k of Object.keys(s.perFile)) allFileKeys.add(k);
const fileRows = [...allFileKeys].sort().map((key) => {
  const values = summaries.map((s) => s.perFile[key] ?? "—");
  const disagree = new Set(values).size > 1;
  return { key, values, disagree };
});

// ---------------------------------------------------------------- report
const md = [];
md.push("# Plannotator version-matrix report");
md.push("");
md.push(`Generated: ${new Date().toISOString()}`);
md.push(`Versions: ${summaries.map((s) => s.version).join(", ")}`);
md.push("");
md.push("All captures are the **since-base** view of the same fixture repo");
md.push("(feature/spaceship: committed dir rename etoro/ -> spaceship/ +");
md.push("file rename Card.tsx -> Panel.tsx, uncommitted edits, whitespace-only");
md.push("change, unstaged deletion, mode-only change, modified ~6MB text file,");
md.push("untracked files). Cells marked ⚠ disagree across versions.");
md.push("");

md.push("## Version × metric matrix");
md.push("");
md.push(`| metric | ${summaries.map((s) => s.version).join(" | ")} |`);
md.push(`|---|${summaries.map(() => "---").join("|")}|`);
for (const r of rows) {
  const flag = r.disagree ? " ⚠" : "";
  md.push(`| ${r.label}${flag} | ${r.values.map((v) => String(v).replace(/\|/g, "\\|")).join(" | ")} |`);
}
md.push("");

md.push("## Per-file matrix (status / hunks / +adds/-dels)");
md.push("");
md.push(`| file | ${summaries.map((s) => s.version).join(" | ")} | git truth |`);
md.push(`|---|${summaries.map(() => "---").join("|")}|---|`);
for (const r of fileRows) {
  const flag = r.disagree ? " ⚠" : "";
  let truthCell = "—";
  if (truth.available) {
    const st = truth.status[r.key];
    const ns = truth.numstat[r.key] ?? truth.numstat[r.key.split(" -> ").pop()];
    if (st) truthCell = `${st}${ns ? ` +${ns.adds ?? "-"}/-${ns.dels ?? "-"}` : ""}`;
    else if (truth.untracked.includes(r.key)) truthCell = "untracked (A)";
  }
  md.push(`| \`${r.key}\`${flag} | ${r.values.join(" | ")} | ${truthCell} |`);
}
md.push("");

// Disagreement deltas vs git truth.
const disagreements = rows.filter((r) => r.disagree);
md.push("## Disagreements");
md.push("");
if (disagreements.length === 0 && !fileRows.some((r) => r.disagree)) {
  md.push("All versions agree on every captured metric.");
} else {
  for (const r of disagreements) {
    md.push(`### ${r.label}`);
    md.push("");
    summaries.forEach((s, i) => {
      md.push(`- **${s.version}**: ${r.values[i]}`);
    });
    if (truth.available) {
      if (r.label === "total +") md.push(`- **git truth**: tracked +${truth.trackedTotals.adds} (since-base incl. untracked: +${truth.sinceBaseTotals.adds})`);
      if (r.label === "total -") md.push(`- **git truth**: -${truth.trackedTotals.dels}`);
      if (r.label === "file count") md.push(`- **git truth**: ${truth.sinceBaseTotals.files} (tracked ${Object.keys(truth.numstat).length} + untracked ${truth.untracked.length})`);
      if (r.label === "renames in patch")
        md.push(`- **git truth (-M)**: ${Object.entries(truth.status).filter(([, c]) => c.startsWith("R")).map(([k, c]) => `${k} (${c})`).join("; ") || "none"}`);
      if (r.label === "deletions")
        md.push(`- **git truth**: ${Object.entries(truth.status).filter(([, c]) => c === "D").map(([k]) => k).join("; ") || "none"}`);
    }
    md.push("");
  }
  const fileDisagreements = fileRows.filter((r) => r.disagree);
  if (fileDisagreements.length > 0) {
    md.push("### Per-file deltas");
    md.push("");
    for (const r of fileDisagreements) {
      md.push(`- \`${r.key}\`: ${summaries.map((s, i) => `${s.version}=${r.values[i]}`).join("; ")}`);
    }
    md.push("");
  }
}

// Sections detail (only when versions disagree on membership).
const sectionsJson = summaries.map((s) => JSON.stringify(s.sections));
if (new Set(sectionsJson).size > 1) {
  md.push("## Sections membership detail");
  md.push("");
  for (const s of summaries) {
    md.push(`### ${s.version}`);
    if (!s.sections) {
      md.push("- n/a");
    } else {
      for (const g of ["committed", "changes", "untracked"]) {
        md.push(`- **${g}** (${s.sections[g].length}): ${s.sections[g].join(", ") || "—"}`);
      }
    }
    md.push("");
  }
}

if (truth.available) {
  md.push("## Git ground truth");
  md.push("");
  md.push(`- merge-base(main, HEAD): \`${truth.mergeBase}\``);
  md.push(`- tracked totals (git diff -M --numstat, no size threshold): +${truth.trackedTotals.adds}/-${truth.trackedTotals.dels} across ${Object.keys(truth.numstat).length} files`);
  md.push(`- untracked files: ${truth.untracked.join(", ") || "none"}`);
  md.push(`- since-base equivalent totals (tracked + untracked lines): +${truth.sinceBaseTotals.adds}/-${truth.sinceBaseTotals.dels}`);
  md.push(
    `- name-status (-M): ${Object.entries(truth.status).map(([k, c]) => `${c} ${k}`).join("; ")}`,
  );
  md.push("");
  md.push("Note: current Plannotator runs git with `core.bigFileThreshold=5MB`");
  md.push("(MAX_REVIEW_FILE_CONTENT_BYTES), so on versions enforcing that bound the");
  md.push("~6MB file appears as a binary stub even though raw git (default threshold");
  md.push("512MB) diffs it as text. Versions predating the bound show a text diff.");
  md.push("");
}

writeFileSync(join(OUT_DIR, "report.md"), md.join("\n") + "\n");
writeFileSync(
  join(OUT_DIR, "report.json"),
  JSON.stringify({ summaries, truth, rows, fileRows }, null, 2) + "\n",
);
console.log(`compare: wrote ${join(OUT_DIR, "report.md")}`);
const flagged = rows.filter((r) => r.disagree).length + fileRows.filter((r) => r.disagree).length;
console.log(`compare: ${flagged} disagreeing rows across ${summaries.length} versions`);
