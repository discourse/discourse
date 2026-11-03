const MAX_LIST = 10;
const MAX_NAMES = 5;
const MAX_STRING = 120;
const COMMENT_LIMIT = 60_000;

export const REPRODUCE =
  "node script/bundle_analysis/analyze.mjs --base-ref origin/main --head frontend/discourse/dist";

/** Whether a size change exceeds a `{ percent, kib, combine }` threshold. */
export function exceeds(base, head, { percent, kib: limitKib, combine }) {
  const change = head - base;
  if (change <= 0) {
    return false;
  }
  const overPercent = base === 0 || (change / base) * 100 > percent;
  const overBytes = change > limitKib * 1024;
  return combine === "or" ? overPercent || overBytes : overPercent && overBytes;
}

/**
 * The flagged findings of a report, each with a stable `key` so the comment
 * workflow can tell a new finding from one it already reported.
 */
export function findings(report, budget) {
  if (report.noJsChanges) {
    return [];
  }
  const result = [];

  for (const group of report.movedIntoInitialLoad) {
    if (group.bytes >= budget.movedIntoInitialLoad.kib * 1024) {
      result.push({ key: `moved:${group.bundle}`, type: "moved", group });
    }
  }

  const initial = report.initialLoad;
  if (exceeds(initial.base, initial.head, budget.initialLoad)) {
    result.push({ key: "initial", type: "initial" });
  }

  for (const bundle of report.bundles) {
    if (bundle.status === "new") {
      result.push({ key: `new:${bundle.key}`, type: "new", bundle });
    }
  }

  for (const bundle of report.bundles) {
    if (
      bundle.status === "same" &&
      !bundle.isMain &&
      exceeds(bundle.base.load, bundle.head.load, budget.bundles)
    ) {
      result.push({ key: `grew:${bundle.key}`, type: "grew", bundle });
    }
  }

  for (const edge of report.edges.added) {
    result.push({
      key: `edge:${edge.from}:${edge.to}:${edge.kind}`,
      type: "edge",
      edge,
    });
  }

  return result;
}

export function renderComment(report, budget, { runUrl } = {}) {
  const flagged = findings(report, budget);
  const keys = flagged.map((f) => f.key);
  if (flagged.length === 0) {
    return { keys, body: null };
  }
  const byType = (type) => flagged.filter((f) => f.type === type);
  const initial = report.initialLoad;
  const sections = [];

  const moved = byType("moved");
  if (moved.length) {
    sections.push(
      tableSection(
        "#### ⚠️ Moved into the initial load",
        "This code now downloads on every first page view. If that is unintended, load it with `import()` instead of a static import.",
        ["From bundle", "Size (minified)", "Pulled in by", "Largest modules"],
        ["---", "---:", "---", "---"],
        moved.map(({ group }) => [
          cell(group.name),
          kib(group.bytes),
          group.importers.map(importLine).join("<br>") || "–",
          group.modules
            .slice(0, 3)
            .map((m) => `${cell(m.id)} ${kib(m.bytes)}`)
            .join("<br>"),
        ])
      )
    );
  }

  const grewRows = [];
  if (byType("initial").length) {
    grewRows.push([
      "Initial load",
      kib(initial.base),
      kib(initial.head),
      `**${delta(initial.base, initial.head)}**`,
      topModuleCell(initial.topModules),
    ]);
  }
  for (const { bundle } of byType("grew")) {
    grewRows.push([
      cell(bundle.name),
      kib(bundle.base.load),
      kib(bundle.head.load),
      `**${delta(bundle.base.load, bundle.head.load)}**`,
      topModuleCell(bundle.topModules),
    ]);
  }
  if (grewRows.length) {
    let grewSection = tableSection(
      "#### 📈 Grew over the threshold",
      null,
      ["Bundle", "Before", "After", "Change", "Largest addition (minified)"],
      ["---", "---:", "---:", "---:", "---"],
      grewRows
    );
    if (byType("initial").length && initial.topModules.length > 1) {
      grewSection += details(
        "Largest additions to the initial load",
        ["Module", "Change (minified)"],
        ["---", "---:"],
        initial.topModules.map((m) => [
          `${cell(m.id)}${m.added ? " (new)" : ""}`,
          signedKib(m.delta),
        ])
      );
    }
    sections.push(grewSection);
  }

  const added = byType("new");
  if (added.length) {
    sections.push(
      tableSection(
        "#### 🆕 New bundles",
        "Expected when you add an `import()`.",
        ["Bundle", "Type", "Size", "Loaded by", "Entry module"],
        ["---", "---", "---:", "---", "---"],
        added.map(({ bundle }) => {
          const from = bundle.importedBy[0];
          return [
            cell(bundle.name),
            bundle.kind,
            kib(bundle.head.load),
            from ? `${cell(from.fromName)}${viaText(from.examples)}` : "–",
            cell(bundle.facade),
          ];
        })
      )
    );
  }

  const edges = byType("edge");
  if (edges.length) {
    sections.push(
      tableSection(
        "#### 🔗 New connections",
        "Loading the first bundle can now load the second.",
        ["From", "To", "Import", "Imported in"],
        ["---", "---", "---", "---"],
        groupEdges(edges.map((f) => f.edge)).map((group) => [
          `${group.from.map(cell).join(", ")}${group.more ? ` and ${group.more} more` : ""}`,
          cell(group.toName),
          group.kind,
          group.examples[0] ? cell(group.examples[0].from) : "–",
        ])
      )
    );
  }

  const count =
    flagged.length === 1 ? "1 finding" : `${flagged.length} findings`;
  const footer = [
    "---",
    `<sub>Sizes are brotli unless marked minified. Flagged when the initial load grows over ${budget.initialLoad.percent}% ${budget.initialLoad.combine} ${budget.initialLoad.kib} KiB, or another bundle over ${budget.bundles.percent}% ${budget.bundles.combine} ${budget.bundles.kib} KiB. Informational only.</sub>`,
    `<sub>Reproduce locally: \`${REPRODUCE}\`${runUrl ? ` · [Full report](${runUrl})` : ""}</sub>`,
  ];

  let body = [
    "### 📦 JS bundle changes",
    "",
    `**Initial load:** ${kib(initial.base)} → ${kib(initial.head)} (${delta(initial.base, initial.head)}) · ${count}`,
    "",
    ...sections,
    ...footer,
  ].join("\n");
  if (body.length > COMMENT_LIMIT) {
    body = `${body.slice(0, COMMENT_LIMIT)}\n\n… truncated, see the full report.`;
  }
  return { keys, body };
}

function tableSection(heading, intro, header, align, rows) {
  const shown = rows.slice(0, MAX_LIST);
  const hidden = rows.length - shown.length;
  return [
    heading,
    ...(intro ? [intro, ""] : []),
    tableRow(header),
    tableRow(align),
    ...shown.map(tableRow),
    ...(hidden > 0
      ? [
          tableRow([
            `… and ${hidden} more in the full report`,
            ...header.slice(1).map(() => ""),
          ]),
        ]
      : []),
    "",
  ].join("\n");
}

function details(summary, header, align, rows) {
  return [
    "<details>",
    `<summary>${summary}</summary>`,
    "",
    tableRow(header),
    tableRow(align),
    ...rows.slice(0, MAX_LIST).map(tableRow),
    "",
    "</details>",
    "",
  ].join("\n");
}

function tableRow(cells) {
  return `| ${cells.join(" | ")} |`;
}

function importLine({ from, to }) {
  return `${cell(from)} imports ${cell(to)}`;
}

function topModuleCell(modules) {
  const top = modules[0];
  return top ? `${cell(top.id)} ${signedKib(top.delta)}` : "–";
}

function viaText(examples) {
  const example = examples?.[0];
  return example ? ` from ${cell(example.from)}` : "";
}

export function renderSummary(report, budget) {
  if (report.noJsChanges) {
    return "### JS bundle analysis\n\nNo JS inputs changed, nothing to compare.\n";
  }
  const flaggedKeys = new Set(findings(report, budget).map((f) => f.key));
  const initial = report.initialLoad;
  const lines = [
    "### JS bundle analysis",
    "",
    "Sizes are brotli (quality 11) unless marked minified.",
    "",
    "| | Base | Head | Change |",
    "| --- | ---: | ---: | ---: |",
    `| Initial load (${initial.chunks.head} chunks) | ${kib(initial.base)} | ${kib(initial.head)} | ${delta(initial.base, initial.head)} |`,
    `| ${cell("discourse")} entry chunk | ${kib(initial.entryOwn.base)} | ${kib(initial.entryOwn.head)} | ${delta(initial.entryOwn.base, initial.entryOwn.head)} |`,
    `| All JS (${report.totals.chunks.head} chunks) | ${kib(report.totals.base)} | ${kib(report.totals.head)} | ${delta(report.totals.base, report.totals.head)} |`,
    "",
  ];

  if (initial.topModules.length) {
    lines.push("**Initial load, largest additions (minified)**", "");
    lines.push(...initial.topModules.map(moduleLine), "");
  }

  if (report.movedIntoInitialLoad.length) {
    lines.push("**Moved into the initial load**", "");
    for (const group of report.movedIntoInitialLoad) {
      lines.push(
        `- ${code(group.name)}: ${kib(group.bytes)} minified${group.importers.length ? `, pulled in by ${group.importers.map(importLine).join(", ")}` : ""}`
      );
    }
    lines.push("");
  }

  lines.push(
    "**Bundles** (load cost: the bundle plus what it loads beyond the initial load)",
    "",
    "| Bundle | Kind | Status | Own size | Load cost base | Load cost head | Change |",
    "| --- | --- | --- | ---: | ---: | ---: | ---: |"
  );
  for (const bundle of report.bundles) {
    const flag =
      flaggedKeys.has(`grew:${bundle.key}`) ||
      flaggedKeys.has(`new:${bundle.key}`)
        ? " ⚠️"
        : "";
    const status = bundle.movedToInitialLoad
      ? "moved into initial load"
      : bundle.status;
    lines.push(
      `| ${cell(bundle.name)}${flag} | ${bundle.kind} | ${status} | ${bundle.head ? kib(bundle.head.own) : "–"} | ${bundle.base ? kib(bundle.base.load) : "–"} | ${bundle.head ? kib(bundle.head.load) : "–"} | ${bundle.base && bundle.head ? delta(bundle.base.load, bundle.head.load) : "–"} |`
    );
  }
  lines.push("");

  for (const [title, list] of [
    ["New connections", report.edges.added],
    ["Removed connections", report.edges.removed],
  ]) {
    if (list.length) {
      lines.push(`**${title}**`, "");
      for (const edge of list) {
        lines.push(
          `- ${code(edge.fromName)} → ${code(edge.toName)}: ${edge.kind}${exampleText(edge.examples)}`
        );
      }
      lines.push("");
    }
  }

  const changedAssets = report.assets.filter((a) => a.base !== a.head);
  lines.push(
    `**Other assets** (wasm and worker files, ${report.assets.length} total, ${changedAssets.length} changed)`,
    ""
  );
  if (changedAssets.length) {
    lines.push("| Asset | Base | Head |", "| --- | ---: | ---: |");
    for (const asset of changedAssets) {
      lines.push(
        `| ${cell(asset.label)} | ${asset.base === null ? "–" : kib(asset.base)} | ${asset.head === null ? "–" : kib(asset.head)} |`
      );
    }
    lines.push("");
  }

  if (report.duplicatePackages.length) {
    lines.push("**Packages bundled in more than one version**", "");
    for (const pkg of report.duplicatePackages) {
      lines.push(
        `- ${code(pkg.name)}: ${pkg.versions.map(code).join(", ")}${pkg.new ? " (new)" : ""}`
      );
    }
    lines.push("");
  }

  lines.push(`Reproduce locally: \`${REPRODUCE}\``, "");
  return lines.join("\n");
}

/** Groups edges that share a target and kind, e.g. from one shared chunk. */
function groupEdges(edges) {
  const groups = new Map();
  for (const edge of edges) {
    const key = `${edge.to}|${edge.kind}`;
    if (!groups.has(key)) {
      groups.set(key, {
        toName: edge.toName,
        kind: edge.kind,
        from: [],
        examples: edge.examples,
      });
    }
    groups.get(key).from.push(edge.fromName);
  }
  return [...groups.values()].map((group) => ({
    ...group,
    from: group.from.slice(0, MAX_NAMES),
    more: Math.max(0, group.from.length - MAX_NAMES),
  }));
}

function exampleText(examples) {
  const example = examples?.[0];
  return example ? `, from ${code(example.from)}` : "";
}

function moduleLine(module) {
  return `- ${code(module.id)} ${signedKib(module.delta)}${module.added ? " (new)" : ""}`;
}

function delta(base, head) {
  const change = head - base;
  if (change === 0) {
    return "0";
  }
  const percent = base > 0 ? `, ${percentChange(change, base)}` : "";
  return `${signedKib(change)}${percent}`;
}

function percentChange(change, base) {
  const percent = (change / base) * 100;
  if (Math.abs(percent) < 0.1) {
    return `${change > 0 ? "+" : "-"}<0.1%`;
  }
  return `${change > 0 ? "+" : ""}${percent.toFixed(1)}%`;
}

export function kib(bytes) {
  if (Math.abs(number(bytes)) < 1024) {
    return `${bytes} B`;
  }
  const value = bytes / 1024;
  const digits = Math.abs(value) < 10 ? 1 : 0;
  return `${value.toLocaleString("en-US", {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  })} KiB`;
}

function signedKib(bytes) {
  return `${number(bytes) > 0 ? "+" : ""}${kib(bytes)}`;
}

function number(value) {
  if (!Number.isFinite(value)) {
    throw new Error(`Expected a number, got ${typeof value}`);
  }
  return value;
}

/**
 * Inline code for strings that come from the build (module ids, bundle
 * names). Code spans keep them from rendering as markdown, links or
 * mentions; the fence is longer than any backtick run inside.
 */
export function code(value) {
  let text = String(value).replace(/[\u0000-\u001f\u007f\u2028\u2029]/g, " ");
  if (text.length > MAX_STRING) {
    const half = Math.floor((MAX_STRING - 1) / 2);
    text = `${text.slice(0, half)}…${text.slice(-half)}`;
  }
  const longestRun = Math.max(
    0,
    ...(text.match(/`+/g) ?? []).map((run) => run.length)
  );
  const fence = "`".repeat(longestRun + 1);
  const pad =
    text.startsWith("`") || text.endsWith("`") || text.trim() !== text
      ? " "
      : "";
  return `${fence}${pad}${text}${pad}${fence}`;
}

/** `code()` for table cells, where a pipe would end the cell. */
function cell(value) {
  return code(value).replaceAll("|", "\\|");
}
