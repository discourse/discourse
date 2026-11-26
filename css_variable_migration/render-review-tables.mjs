// Renders the Markdown review tables in review/ from the JSON files.
import {
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import postcssScss from "postcss-scss";
import { format } from "prettier";
import createGrammar from "../frontend/asset-processor/css-variable-grammar.mjs";
import { BASE_LAYER_FILE, listFiles, ROOT } from "./mapping.mjs";

const HERE = join(ROOT, "css_variable_migration");
const REVIEW = join(HERE, "review");
const UNDECIDED_FILE = "tmp/css_variable_migration/undecided.json";

// The stylesheets that `pnpm lint:css` checks.
const LINTED =
  /^(app\/assets\/stylesheets\/|plugins\/[^/]+\/assets\/stylesheets\/|themes\/)/;
const CORE_COMPONENTS =
  /^app\/assets\/stylesheets\/common\/(components|ui-kit)\//;
// A name that only tests or docs mention besides its stylesheet is still internal.
const NOT_A_USE = /(^|\/)(tests?|spec)\/|\.md$|^css_variable_migration\//;

const mapping = readJson(join(HERE, "mapping.json"));
const definitions = readJson(join(HERE, "definitions.json"));
const declaredIn = findDeclarations();
const rows = mappingRows();

const SCOPES = {
  system: {
    file: "system.md",
    title: "System tokens",
    shows: "Entries that map to `--d-sys-*` tokens, by property",
    section: (row) => systemSection(row.target),
  },
  components: {
    file: "components.md",
    title: "Component tokens",
    shows: "Entries that map to `--d-comp-*` tokens, by component",
    section: (row) => row.target.split("-")[4],
  },
  plugins: {
    file: "plugins.md",
    title: "Plugin tokens",
    shows: "Entries that map to `--p-*` tokens, by plugin",
    section: (row) => row.target.split("-")[3],
  },
  base: {
    file: "base-palette.md",
    title: "Base palette",
    shows:
      "Base, rgb and split variables, entries that map to base variables, and drops without a successor",
    section: baseSection,
  },
};

const pages = [];

for (const [scope, { file, title, section }] of Object.entries(SCOPES)) {
  const scoped = rows.filter((row) => row.scope === scope);
  const extra = scope === "base" ? splitOverviewRows() : [];
  pages.push({
    file,
    entries: scoped.length,
    open: scoped.filter((row) => row.open).length,
    body: [
      `# ${title}`,
      generatedNote("mapping.json"),
      ...grouped([...scoped, ...extra], section).map(
        ([name, sectionRows]) => `## ${name}\n\n${scopeTable(sectionRows)}`
      ),
    ],
  });
}

pages.push({
  file: "mapping.md",
  entries: Object.values(mapping).reduce(
    (sum, entries) => sum + Object.keys(entries).length,
    0
  ),
  open: rows.filter((row) => row.open).length,
  body: [
    "# CSS variable mapping",
    generatedNote("mapping.json"),
    ...Object.entries(mapping).map(
      ([kind, entries]) =>
        `## ${capitalize(kind)}\n\n${kindTable(kind, entries)}`
    ),
  ],
});

pages.push({
  file: "definitions.md",
  entries: Object.keys(definitions).length,
  open: 0,
  body: [
    "# Definitions",
    generatedNote("definitions.json"),
    table(
      ["Variable", "Value", "Stylesheet", "Insert after"],
      Object.entries(definitions).map(([name, { value, file, after }]) => [
        code(name),
        code(value),
        fileLink(file),
        code(after),
      ])
    ),
  ],
});

pages.push(todoPage());
pages.push(unmappedPage());

rmSync(REVIEW, { recursive: true, force: true });
mkdirSync(REVIEW);
await write("README.md", indexPage());
for (const { file, body } of pages) {
  await write(file, body);
}

function mappingRows() {
  const result = [];
  const add = (row) => result.push({ ...row, scope: scopeOf(row) });

  for (const [kind, entries] of Object.entries(mapping)) {
    for (const [old, entry] of Object.entries(entries)) {
      const { note, open } = typeof entry === "object" ? entry : {};
      if (kind === "split") {
        const roles = splitRoles(entry);
        if (!roles.length) {
          add({ old, kind, note, open: open ?? "No roles yet." });
        }
        for (const [role, target] of roles) {
          add({ old, kind, role, target, note, open });
        }
      } else if (kind === "border") {
        add({ old, kind, role: "width", target: entry.width, note, open });
        add({ old, kind, role: "color", target: entry.color, note, open });
      } else if (typeof entry === "string") {
        add(
          kind === "base" || kind === "drop"
            ? { old, kind, note: entry }
            : { old, kind, target: entry }
        );
      } else {
        add({ old, kind, target: entry.to, note, open });
      }
    }
  }
  return result;
}

function splitRoles(entry) {
  return Object.entries(entry).filter(
    ([key]) => key !== "note" && key !== "open"
  );
}

// The full split entry, so the base palette shows every job of a base variable.
function splitOverviewRows() {
  return Object.entries(mapping.split ?? {}).map(([old, entry]) => ({
    old,
    kind: "split",
    target: null,
    targets: splitRoles(entry),
    note: entry.note,
    open: entry.open,
    overview: true,
  }));
}

function scopeOf({ kind, target }) {
  if (target?.startsWith("--d-sys-")) {
    return "system";
  }
  if (target?.startsWith("--d-comp-")) {
    return "components";
  }
  if (target?.startsWith("--p-")) {
    return "plugins";
  }
  return kind === "split" && !target ? null : "base";
}

function systemSection(target) {
  const [category, part] = target.replace("--d-sys-", "").split("-");
  return category === "color" ? `color-${part}` : category;
}

function baseSection(row) {
  if (row.overview) {
    return "Split";
  }
  if (row.kind === "split") {
    return "Split uses that keep the base variable";
  }
  if (row.kind === "drop") {
    return "Dropped without a successor";
  }
  if (row.kind === "base" || row.kind === "rgb") {
    return capitalize(row.kind);
  }
  return "Mapped to base variables";
}

function grouped(list, section) {
  const groups = new Map();
  for (const row of list) {
    const name = section(row);
    groups.set(name, [...(groups.get(name) ?? []), row]);
  }
  return [...groups].sort(([a], [b]) => a.localeCompare(b));
}

function scopeTable(list) {
  const sorted = [...list].sort(
    (a, b) =>
      (a.target ?? "").localeCompare(b.target ?? "") ||
      a.old.localeCompare(b.old)
  );
  return table(
    ["Old variable", "New token", "Kind", "Defined in", "Notes"],
    sorted.map((row) => [
      code(row.old),
      row.targets
        ? row.targets
            .map(([role, target]) => `${code(role)} → ${code(target)}`)
            .join("<br>")
        : code(row.target),
      row.role ? `${row.kind} (${code(row.role)})` : row.kind,
      definedIn(row),
      notes(row),
    ])
  );
}

function definedIn({ old, target }) {
  const files =
    (target?.startsWith("--") && declaredIn.get(target)) ||
    declaredIn.get(old) ||
    [];
  return linkFiles(files);
}

function notes({ note, open }) {
  return [open && `**Open:** ${escapeCell(open)}`, escapeCell(note)]
    .filter(Boolean)
    .join("<br>");
}

function kindTable(kind, entries) {
  if (kind === "border") {
    return table(
      ["Old variable", "Width token", "Color token", "Style", "Notes"],
      Object.entries(entries).map(([name, entry]) => [
        code(name),
        code(entry.width),
        code(entry.color),
        code(entry.style ?? "solid"),
        notes(entry),
      ])
    );
  }

  if (kind === "split") {
    return table(
      ["Base variable", "Target by role", "Notes"],
      Object.entries(entries).map(([name, entry]) => [
        code(name),
        splitRoles(entry)
          .map(([role, target]) => `${code(role)} → ${code(target)}`)
          .join("<br>"),
        notes(entry),
      ])
    );
  }

  const list = Object.entries(entries).map(([name, entry]) => {
    const fields =
      typeof entry === "string"
        ? kind === "base" || kind === "drop"
          ? { note: entry }
          : { to: entry }
        : entry;
    return kind === "base"
      ? [code(name), notes(fields)]
      : [code(name), code(fields.to), notes(fields)];
  });
  return table(
    kind === "base"
      ? ["Base variable", "Notes"]
      : ["Old variable", "Target", "Notes"],
    list
  );
}

function todoPage() {
  const open = rows.filter((row) => row.open);
  const decisions = [
    ...new Map(open.map((row) => [`${row.kind} ${row.old}`, row])).values(),
  ];
  const body = [
    "# Open items",
    `Generated from [mapping.json](../mapping.json) and \`${UNDECIDED_FILE}\`. Run \`node css_variable_migration/render-review-tables.mjs\` to regenerate this page. The process checklist is in [TODO.md](../TODO.md).`,
    "## Open decisions",
    "Entries with an `open` question, and split entries without roles.",
    table(
      ["Old variable", "Kind", "Scopes", "Question", "Notes"],
      decisions.map((row) => [
        code(row.old),
        row.kind,
        [
          ...new Set(
            open
              .filter((o) => o.old === row.old && o.kind === row.kind)
              .map((o) => (o.scope ? SCOPES[o.scope].file : "base-palette.md"))
          ),
        ]
          .map((file) => `[${file.replace(".md", "")}](${file})`)
          .join(", "),
        escapeCell(row.open),
        escapeCell(row.note),
      ])
    ),
  ];

  const undecidedPath = join(ROOT, UNDECIDED_FILE);
  let undecidedCount = 0;
  if (!existsSync(undecidedPath)) {
    body.push(
      "## Undecided split reads",
      "Run `node css_variable_migration/apply.mjs` to list them, then regenerate this page."
    );
  } else {
    const reads = [];
    for (const [file, rules] of Object.entries(readJson(undecidedPath))) {
      for (const [rule, props] of Object.entries(rules)) {
        for (const [prop, names] of Object.entries(props)) {
          for (const name of names) {
            reads.push({ file, rule, prop, name, owner: ownerOf(file) });
          }
        }
      }
    }
    undecidedCount = reads.length;
    const counts = (key) =>
      [...Map.groupBy(reads, (read) => read[key])]
        .map(([value, list]) => [value, list.length])
        .sort(([, a], [, b]) => b - a);

    body.push(
      "## Undecided split reads",
      "Split reads with no role in their split entry and no override, from the last codemod run. Each needs a role in `mapping.json` or an override in `overrides.json`.",
      "### By base variable",
      table(
        ["Base variable", "Reads"],
        counts("name").map(([name, count]) => [code(name), count])
      ),
      "### By owner",
      table(
        ["Owner", "Reads"],
        counts("owner").map(([owner, count]) => [owner, count])
      ),
      ...[...Map.groupBy(reads, (read) => read.owner)]
        .sort(([a], [b]) =>
          a === "Core" ? -1 : b === "Core" ? 1 : a.localeCompare(b)
        )
        .map(
          ([owner, list]) =>
            `### ${owner}\n\n${table(
              ["Stylesheet", "Rule", "Property", "Base variable"],
              list.map(({ file, rule, prop, name }) => [
                fileLink(file),
                code(rule),
                code(prop),
                code(name),
              ])
            )}`
        )
    );
  }

  return {
    file: "todo.md",
    entries: decisions.length + undecidedCount,
    open: decisions.length + undecidedCount,
    body,
  };
}

function ownerOf(file) {
  const plugin = file.match(/^plugins\/([^/]+)\//);
  if (plugin) {
    return plugin[1];
  }
  const theme = file.match(/^themes\/([^/]+)\//);
  return theme ? `Theme: ${theme[1]}` : "Core";
}

function indexPage() {
  return [
    "# CSS variable migration review",
    "Generated by `node css_variable_migration/render-review-tables.mjs`. Do not edit these files. [mapping.json](../mapping.json) and [definitions.json](../definitions.json) are the source of truth.",
    "A split entry appears in every scope that one of its roles maps into. The base palette also shows each split entry whole.",
    table(
      ["Table", "Shows", "Rows", "Open"],
      [
        ["todo.md", "Open decisions and undecided split reads"],
        [
          "unmapped.md",
          "Declared names that break the naming scheme, so they need a mapping entry",
        ],
        ...Object.values(SCOPES).map(({ file, shows }) => [file, shows]),
        ["mapping.md", "Every mapping entry, grouped as the codemod reads it"],
        [
          "definitions.md",
          "Values for new variables, or new values for existing ones",
        ],
      ].map(([file, shows]) => {
        const page = pages.find((p) => p.file === file);
        return [`[${file}](${file})`, shows, page.entries, page.open || ""];
      })
    ),
  ];
}

// Every file that declares each variable, so reviewers can find where a token is defined.
function findDeclarations() {
  const result = new Map();
  for (const file of listFiles().filter((f) => /\.s?css$/.test(f))) {
    let root;
    try {
      root = postcssScss.parse(readFileSync(join(ROOT, file), "utf8"));
    } catch {
      // Test fixtures include deliberately broken stylesheets.
      continue;
    }
    root.walkDecls((decl) => {
      if (!decl.prop.startsWith("--")) {
        return;
      }
      const files = result.get(decl.prop) ?? [];
      if (!files.includes(file)) {
        files.push(file);
        result.set(decl.prop, files);
      }
    });
  }
  return result;
}

// Every file that mentions each variable, apart from tests and docs.
function findUses() {
  const result = new Map();
  for (const file of listFiles().filter((f) => !NOT_A_USE.test(f))) {
    const text = readFileSync(join(ROOT, file), "utf8");
    for (const [name] of text.matchAll(/--[a-zA-Z0-9][\w-]*/g)) {
      if (!result.has(name)) {
        result.set(name, new Set());
      }
      result.get(name).add(file);
    }
  }
  return result;
}

function unmappedOwner(file) {
  const owner = ownerOf(file);
  if (owner !== "Core") {
    return owner;
  }
  return CORE_COMPONENTS.test(file) ? "Core components" : "Core, other";
}

function ownerGroup(owner) {
  if (owner.startsWith("Core")) {
    return owner;
  }
  return owner.startsWith("Theme: ") ? "Bundled themes" : "Bundled plugins";
}

// Same check as the discourse/css-variable-names lint rule, per name instead of per declaration.
function unmappedPage() {
  const parse = createGrammar(
    readJson(join(ROOT, "app/assets/stylesheets/variable-vocabulary.json"))
  );
  const baseLayer = readJson(join(ROOT, BASE_LAYER_FILE));
  const usedIn = findUses();
  const failing = [];
  for (const [name, allFiles] of declaredIn) {
    const files = allFiles.filter((file) => LINTED.test(file));
    if (!files.length || Object.hasOwn(baseLayer, name)) {
      continue;
    }
    const [reason] = parse(name).errors;
    if (reason) {
      failing.push({
        name,
        reason,
        files,
        uses: usedIn.get(name)?.size ?? 0,
        owner: unmappedOwner(files[0]),
      });
    }
  }

  const rank = (owner) =>
    ["Core components", "Core, other"].indexOf(owner) + 1 || 3;
  const byOwner = [...Map.groupBy(failing, (item) => item.owner)].sort(
    ([a, x], [b, y]) =>
      rank(a) - rank(b) || y.length - x.length || a.localeCompare(b)
  );
  const summary = (groups) =>
    table(
      ["Owner", "Names", "Used in one file", "Used in several files"],
      groups.map(([owner, list]) => {
        const single = list.filter((item) => item.uses <= 1).length;
        return [owner, list.length, single, list.length - single];
      })
    );
  const groupOrder = [
    "Core components",
    "Core, other",
    "Bundled plugins",
    "Bundled themes",
  ];
  const byGroup = [
    ...Map.groupBy(failing, (item) => ownerGroup(item.owner)),
  ].sort(([a], [b]) => groupOrder.indexOf(a) - groupOrder.indexOf(b));

  return {
    file: "unmapped.md",
    entries: failing.length,
    open: failing.length,
    body: [
      "# Names without a mapping entry",
      "Declared names that break the naming scheme, checked with the grammar that the `discourse/css-variable-names` lint rule uses. Each needs an entry in [mapping.json](../mapping.json). Reads of split variables are in [todo.md](todo.md).",
      "Core components are the names first declared in `common/components` or `common/ui-kit`. The split follows the stylesheet's folder, so a name such as a sidebar variable in `common/base` counts as other core. Used in counts the files that mention the name, apart from tests and docs. A name used in one file is internal to its stylesheet.",
      `Run \`node css_variable_migration/render-review-tables.mjs\` to regenerate this page. See the [index](README.md) for the other tables.`,
      "## Summary",
      summary([...byGroup, ["Total", failing]]),
      "## By owner",
      summary(byOwner),
      ...byOwner.map(
        ([owner, list]) =>
          `## ${owner}\n\n${table(
            ["Variable", "Declared in", "Used in", "Reason"],
            list
              .sort((a, b) => a.name.localeCompare(b.name))
              .map(({ name, files, uses, reason }) => [
                code(name),
                linkFiles(files),
                uses === 1 ? "1 file" : `${uses} files`,
                escapeCell(reason),
              ])
          )}`
      ),
    ],
  };
}

function linkFiles(files) {
  const shown = files.slice(0, 2).map(fileLink);
  if (files.length > 2) {
    shown.push(`+${files.length - 2} more`);
  }
  return shown.join("<br>");
}

function generatedNote(source) {
  return `Generated from [${source}](../${source}). Edit the JSON and run \`node css_variable_migration/render-review-tables.mjs\` to regenerate this page. See the [index](README.md) for the other tables.`;
}

async function write(file, parts) {
  writeFileSync(
    join(REVIEW, file),
    await format(parts.join("\n\n"), { parser: "markdown" })
  );
}

function table(headers, list) {
  if (!list.length) {
    return "None.";
  }
  const line = (cells) => `| ${cells.join(" | ")} |`;
  return [
    line(headers),
    line(headers.map(() => "---")),
    ...list.map(line),
  ].join("\n");
}

function fileLink(file) {
  return `[${escapeCell(file.split("/").at(-1))}](../../${file})`;
}

function code(value) {
  return value == null ? "" : `\`${escapeCell(value)}\``;
}

function escapeCell(value) {
  return String(value ?? "")
    .replaceAll("|", "\\|")
    .replaceAll("\n", "<br>");
}

function capitalize(text) {
  return text[0].toUpperCase() + text.slice(1);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}
