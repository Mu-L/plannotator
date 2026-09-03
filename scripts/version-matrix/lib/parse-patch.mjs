// parse-patch.mjs — parse a git unified diff (Plannotator rawPatch) into
// machine-comparable stats. Used by run.sh (writes stats.json) and compare.mjs.
//
// CLI: node parse-patch.mjs <diff.json|patch-file>
//   *.json input: reads the "rawPatch" field; otherwise treats file as raw patch.
//   Prints stats JSON to stdout.

import { readFileSync } from "node:fs";

function unquoteGitPath(p) {
  if (p.startsWith('"') && p.endsWith('"')) {
    // Minimal C-style unquote (good enough for fixture paths).
    return p
      .slice(1, -1)
      .replace(/\\t/g, "\t")
      .replace(/\\n/g, "\n")
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, "\\");
  }
  return p;
}

function stripPrefix(p) {
  if (p === "/dev/null") return null;
  return p.replace(/^[ab]\//, "");
}

export function parsePatch(rawPatch) {
  const files = [];
  if (!rawPatch || typeof rawPatch !== "string" || rawPatch.trim() === "") {
    return { files, totals: { adds: 0, dels: 0, files: 0 } };
  }
  const lines = rawPatch.split("\n");
  let cur = null;

  const flush = () => {
    if (cur) files.push(cur);
    cur = null;
  };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith("diff --git ")) {
      flush();
      // diff --git a/<old> b/<new> (paths may be quoted)
      // Fixture paths contain no spaces, so splitting at the last ' b/' (or
      // ' "b/') is reliable; unquote handles git's quoted-path form.
      const rest = line.slice("diff --git ".length);
      let idx = rest.lastIndexOf(' "b/');
      if (idx === -1) idx = rest.lastIndexOf(" b/");
      let oldP = null;
      let newP = null;
      if (idx !== -1) {
        oldP = stripPrefix(unquoteGitPath(rest.slice(0, idx).trim()));
        newP = stripPrefix(unquoteGitPath(rest.slice(idx + 1).trim()));
      } else {
        const parts = rest.split(" ");
        oldP = stripPrefix(unquoteGitPath(parts[0] ?? ""));
        newP = stripPrefix(unquoteGitPath(parts[1] ?? parts[0] ?? ""));
      }
      cur = {
        path: newP ?? oldP,
        oldPath: oldP,
        newPath: newP,
        status: "M",
        renameFrom: null,
        renameTo: null,
        oldMode: null,
        newMode: null,
        binary: false,
        hunks: 0,
        adds: 0,
        dels: 0,
      };
      continue;
    }
    if (!cur) continue;
    if (line.startsWith("new file mode ")) {
      cur.status = "A";
      cur.newMode = line.slice("new file mode ".length);
      continue;
    }
    if (line.startsWith("deleted file mode ")) {
      cur.status = "D";
      cur.oldMode = line.slice("deleted file mode ".length);
      continue;
    }
    if (line.startsWith("old mode ")) {
      cur.oldMode = line.slice("old mode ".length);
      continue;
    }
    if (line.startsWith("new mode ")) {
      cur.newMode = line.slice("new mode ".length);
      continue;
    }
    if (line.startsWith("rename from ")) {
      cur.renameFrom = unquoteGitPath(line.slice("rename from ".length));
      cur.status = "R";
      continue;
    }
    if (line.startsWith("rename to ")) {
      cur.renameTo = unquoteGitPath(line.slice("rename to ".length));
      cur.status = "R";
      cur.path = cur.renameTo;
      continue;
    }
    if (line.startsWith("Binary files ") || line.startsWith("GIT binary patch")) {
      cur.binary = true;
      continue;
    }
    if (line.startsWith("@@")) {
      cur.hunks++;
      continue;
    }
    if (line.startsWith("+++") || line.startsWith("---")) continue;
    if (line.startsWith("+")) {
      cur.adds++;
      continue;
    }
    if (line.startsWith("-")) {
      cur.dels++;
      continue;
    }
  }
  flush();

  const totals = files.reduce(
    (acc, f) => {
      acc.adds += f.adds;
      acc.dels += f.dels;
      return acc;
    },
    { adds: 0, dels: 0, files: files.length },
  );

  const modeOnly = files
    .filter((f) => f.hunks === 0 && !f.binary && f.status === "M" && f.oldMode && f.newMode)
    .map((f) => f.path);
  const emptyHunkFiles = files
    .filter((f) => f.hunks === 0 && !f.binary && !(f.status === "M" && f.oldMode && f.newMode))
    .map((f) => f.path);
  const binaryFiles = files.filter((f) => f.binary).map((f) => f.path);
  const renames = files
    .filter((f) => f.status === "R")
    .map((f) => `${f.renameFrom ?? f.oldPath} -> ${f.renameTo ?? f.newPath}`);

  return { files, totals, emptyHunkFiles, modeOnlyFiles: modeOnly, binaryFiles, renames };
}

const invokedAsScript = process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop());
if (invokedAsScript) {
  const input = process.argv[2];
  if (!input) {
    console.error("usage: node parse-patch.mjs <diff.json|patch-file>");
    process.exit(2);
  }
  const text = readFileSync(input, "utf8");
  let raw = text;
  if (input.endsWith(".json")) {
    const parsed = JSON.parse(text);
    raw = parsed.rawPatch ?? "";
  }
  process.stdout.write(JSON.stringify(parsePatch(raw), null, 2) + "\n");
}
