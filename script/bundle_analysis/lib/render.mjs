import { MAIN_KEY } from "./graph.mjs";

const MAX_LIST = 10;
const MAX_NAMES = 5;
const MAX_STRING = 120;
const COMMENT_LIMIT = 60_000;

export const HEADING = "### 📦 JS bundle changes";
const REPRODUCE =
  "node script/bundle_analysis/analyze.mjs --base-ref origin/main --build-head";

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
  const add = (type, id, data) =>
    result.push({ key: id ? `${type}:${id}` : type, type, ...data });

  for (const group of report.movedIntoInitialLoad) {
    if (group.bytes >= budget.movedIntoInitialLoad.kib * 1024) {
      add("moved", group.bundle, { group });
    }
  }
  const initial = report.initialLoad;
  if (exceeds(initial.base, initial.head, budget.initialLoad)) {
    add("initial");
  }
  for (const bundle of report.bundles) {
    if (bundle.status === "new") {
      add("new", bundle.key, { bundle });
    } else if (
      bundle.status === "same" &&
      bundle.key !== MAIN_KEY &&
      exceeds(bundle.base.load, bundle.head.load, budget.bundles)
    ) {
      add("grew", bundle.key, { bundle });
    }
  }
  for (const edge of report.edges.added) {
    add("edge", `${edge.from}:${edge.to}:${edge.kind}`, { edge });
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
  const initialGrew = byType("initial").length > 0;
  const growthRow = (name, base, head, topModules) => [
    name,
    kib(base),
    kib(head),
    `**${delta(base, head)}**`,
    topModuleCell(topModules),
  ];
  // Edges into one bundle often come from one shared chunk.
  const edgeGroups = new Map();
  for (const { edge } of byType("edge")) {
    const key = `${edge.to}|${edge.kind}`;
    if (!edgeGroups.has(key)) {
      edgeGroups.set(key, []);
    }
    edgeGroups.get(key).push(edge);
  }

  const sections = [
    tableSection(
      "#### ⚠️ Moved into the initial load",
      "This code now downloads on every first page view. If that is unintended, load it with `import()` instead of a static import.",
      ["From bundle", "Size (unminified)", "Pulled in by", "Largest modules"],
      ["---", "---:", "---", "---"],
      byType("moved").map(({ group }) => [
        cell(group.name),
        kib(group.bytes),
        group.importers.slice(0, 3).map(importLine).join("<br>") || "–",
        group.modules
          .slice(0, 3)
          .map((m) => `${cell(m.id)} ${kib(m.bytes)}`)
          .join("<br>"),
      ])
    ),
    tableSection(
      "#### 📈 Grew over the threshold",
      null,
      ["Bundle", "Before", "After", "Change", "Largest addition (unminified)"],
      ["---", "---:", "---:", "---:", "---"],
      [
        ...(initialGrew
          ? [
              growthRow(
                "Initial load",
                initial.base,
                initial.head,
                initial.topModules
              ),
            ]
          : []),
        ...byType("grew").map(({ bundle }) =>
          growthRow(
            cell(bundle.name),
            bundle.base.load,
            bundle.head.load,
            bundle.topModules
          )
        ),
      ]
    ) +
      (initialGrew && initial.topModules.length > 1
        ? details(
            "Largest additions to the initial load",
            ["Module", "Change (unminified)"],
            ["---", "---:"],
            initial.topModules.map((m) => [
              `${cell(m.id)}${m.added ? " (new)" : ""}`,
              signedKib(m.delta),
            ])
          )
        : ""),
    tableSection(
      "#### 🆕 New bundles",
      "Expected when you add an `import()`.",
      ["Bundle", "Type", "Size", "Loaded by", "Entry module"],
      ["---", "---", "---:", "---", "---"],
      byType("new").map(({ bundle }) => {
        const from = bundle.importedBy[0];
        return [
          cell(bundle.name),
          kindCell(bundle.kind),
          kib(bundle.head.load),
          from
            ? `${cell(from.fromName)}${from.example ? ` from ${cell(from.example.from)}` : ""}`
            : "–",
          cell(bundle.facade),
        ];
      })
    ),
    tableSection(
      "#### 🔗 New connections",
      "Loading the first bundle can now load the second.",
      ["From", "To", "Import", "Imported in"],
      ["---", "---", "---", "---"],
      [...edgeGroups.values()].map((edges) => {
        const [{ toName, kind, example }] = edges;
        const more = edges.length - MAX_NAMES;
        return [
          `${edges
            .slice(0, MAX_NAMES)
            .map((edge) => cell(edge.fromName))
            .join(", ")}${more > 0 ? ` and ${more} more` : ""}`,
          cell(toName),
          kindCell(kind),
          example ? cell(example.from) : "–",
        ];
      })
    ),
  ].filter(Boolean);

  const body = [
    HEADING,
    "",
    `**Initial load:** ${kib(initial.base)} → ${kib(initial.head)} (${delta(initial.base, initial.head)}) · ${flagged.length} finding${flagged.length === 1 ? "" : "s"}`,
    "",
    ...sections,
    "---",
    `<sub>Sizes are brotli unless marked unminified. Flagged when the initial load grows over ${budget.initialLoad.percent}% ${budget.initialLoad.combine} ${budget.initialLoad.kib} KiB, or another bundle over ${budget.bundles.percent}% ${budget.bundles.combine} ${budget.bundles.kib} KiB. Informational only.</sub>`,
    `<sub>Reproduce locally: \`${REPRODUCE}\`${runUrl ? ` · [Full report](${runUrl})` : ""}</sub>`,
  ].join("\n");
  return { keys, body: truncate(body, runUrl) };
}

/** Cuts at a line end: code spans never hold one, so none is left open. */
export function truncate(body, runUrl, limit = COMMENT_LIMIT) {
  if (body.length <= limit) {
    return body;
  }
  const report = runUrl ? `[full report](${runUrl})` : "full report";
  return `${body.slice(0, body.lastIndexOf("\n", limit))}\n\n… truncated, see the ${report}.`;
}

function tableSection(heading, intro, header, align, rows) {
  if (!rows.length) {
    return "";
  }
  const hidden = rows.length - MAX_LIST;
  return [
    heading,
    ...(intro ? [intro, ""] : []),
    tableRow(header),
    tableRow(align),
    ...rows.slice(0, MAX_LIST).map(tableRow),
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

function details(summary, ...table) {
  // The empty heading line ends the HTML block, so the table renders.
  return `<details>\n<summary>${summary}</summary>\n${tableSection("", null, ...table)}\n</details>\n`;
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

export function renderSummary(report, budget) {
  if (report.noJsChanges) {
    return "### JS bundle analysis\n\nNo JS inputs changed, nothing to compare.\n";
  }
  const flagged = new Set(findings(report, budget).map((f) => f.bundle));
  const movedKeys = new Set(report.movedIntoInitialLoad.map((g) => g.bundle));
  const initial = report.initialLoad;
  const sizeRow = (label, { base, head }) =>
    `| ${label} | ${kib(base)} | ${kib(head)} | ${delta(base, head)} |`;
  const lines = [
    "### JS bundle analysis",
    "",
    "Sizes are brotli (quality 11) unless marked otherwise.",
    "",
    "| | Base | Head | Change |",
    "| --- | ---: | ---: | ---: |",
    sizeRow(`Initial load (${initial.chunks.head} chunks)`, initial),
    sizeRow(`${cell("discourse")} entry chunk`, initial.entryOwn),
    sizeRow(`All JS (${report.totals.chunks.head} chunks)`, report.totals),
    "",
  ];
  const list = (title, items) => {
    if (items.length) {
      lines.push(`**${title}**`, "", ...items, "");
    }
  };
  const edgeLine = (edge) =>
    `- ${code(edge.fromName)} → ${code(edge.toName)}: ${edge.kind}${edge.example ? `, from ${code(edge.example.from)}` : ""}`;

  list(
    "Initial load, largest additions (unminified)",
    initial.topModules.map(
      (m) => `- ${code(m.id)} ${signedKib(m.delta)}${m.added ? " (new)" : ""}`
    )
  );
  list(
    "Moved into the initial load",
    report.movedIntoInitialLoad.map(
      (group) =>
        `- ${code(group.name)}: ${kib(group.bytes)} unminified${group.importers.length ? `, pulled in by ${group.importers.map(importLine).join(", ")}` : ""}`
    )
  );

  lines.push(
    "**Bundles** (load cost: the bundle plus what it loads beyond the initial load)",
    "",
    "| Bundle | Kind | Status | Own size | Load cost base | Load cost head | Change |",
    "| --- | --- | --- | ---: | ---: | ---: | ---: |"
  );
  for (const bundle of report.bundles) {
    const status =
      bundle.status === "removed" && movedKeys.has(bundle.key)
        ? "moved into initial load"
        : bundle.status;
    lines.push(
      `| ${cell(bundle.name)}${flagged.has(bundle) ? " ⚠️" : ""} | ${bundle.kind} | ${status} | ${kib(bundle.head?.own)} | ${kib(bundle.base?.load)} | ${kib(bundle.head?.load)} | ${bundle.base && bundle.head ? delta(bundle.base.load, bundle.head.load) : "–"} |`
    );
  }
  lines.push("");

  list("New connections", report.edges.added.map(edgeLine));
  list("Removed connections", report.edges.removed.map(edgeLine));

  const changedAssets = report.assets.filter((a) => a.base !== a.head);
  lines.push(
    `**Other assets** (wasm and worker files, uncompressed, ${report.assets.length} total, ${changedAssets.length} changed)`,
    ""
  );
  if (changedAssets.length) {
    lines.push("| Asset | Base | Head |", "| --- | ---: | ---: |");
    for (const asset of changedAssets) {
      lines.push(
        `| ${cell(asset.label)} | ${kib(asset.base)} | ${kib(asset.head)} |`
      );
    }
    lines.push("");
  }

  list(
    "Packages bundled in more than one version",
    report.duplicatePackages.map(
      (pkg) =>
        `- ${code(pkg.name)}: ${pkg.versions.map(code).join(", ")}${pkg.new ? " (new)" : ""}`
    )
  );

  lines.push(`Reproduce locally: \`${REPRODUCE}\``, "");
  return lines.join("\n");
}

function delta(base, head) {
  const change = head - base;
  if (change === 0 || base <= 0) {
    return change === 0 ? "0" : signedKib(change);
  }
  const percent = Math.abs((change / base) * 100);
  return `${signedKib(change)}, ${change > 0 ? "+" : "-"}${percent < 0.1 ? "<0.1" : percent.toFixed(1)}%`;
}

/** `–` for a size a build does not have. */
function kib(bytes) {
  if (bytes === null || bytes === undefined) {
    return "–";
  }
  // The report is untrusted; anything else could carry markdown.
  if (!Number.isFinite(bytes)) {
    throw new Error(`Not a size: ${JSON.stringify(bytes)}`);
  }
  if (Math.abs(bytes) < 1024) {
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
  return `${bytes > 0 ? "+" : ""}${kib(bytes)}`;
}

/**
 * Inline code for strings that come from the build (module ids, bundle
 * names). Code spans keep them from rendering as markdown, links or
 * mentions; the fence is longer than any backtick run inside.
 */
export function code(value) {
  // Control and invisible formatting characters, which could end the span or
  // reorder the text around it.
  let text = String(value).replace(
    /[\u0000-\u001f\u007f\u2028\u2029\p{Cf}]/gu,
    " "
  );
  if (text.length > MAX_STRING) {
    const half = Math.floor((MAX_STRING - 1) / 2);
    text = `${text.slice(0, half)}…${text.slice(-half)}`;
  }
  const longestRun = Math.max(
    0,
    ...(text.match(/`+/g) ?? []).map((run) => run.length)
  );
  const fence = "`".repeat(longestRun + 1);
  const pad = /^[\s`]|[\s`]$/.test(text) ? " " : "";
  return `${fence}${pad}${text}${pad}${fence}`;
}

const KINDS = new Set(["entry", "lazy", "static", "dynamic", "url"]);

/** Known bundle and import kinds as plain text, anything else escaped. */
function kindCell(kind) {
  return KINDS.has(kind) ? kind : cell(kind);
}

/** `code()` for table cells, where a pipe would end the cell. */
function cell(value) {
  return code(value).replaceAll("|", "\\|");
}
