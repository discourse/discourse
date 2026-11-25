/* eslint-disable no-console */
// Compiles the stylesheets on the base commit and on HEAD, resolves every var()
// to its final value, and lists the declarations and :root variables whose
// computed value differs, for Foundation and Horizon in light and dark.
// Both sides are compiled twice, and values that differ between two runs of the
// same side, such as Sass random(), are ignored. Scoped overrides on ancestors and values
// set at runtime are not covered.
//
//   node css_variable_migration/compare.mjs [--base REF] [--no-compile]

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { chromium } from "playwright";
import postcss from "postcss";
import valueParser from "postcss-value-parser";
import { loadMapping, ROOT } from "./mapping.mjs";

const OUTPUT = join(ROOT, "tmp/css_variable_migration");
const UNSET = Symbol("unset");
const IGNORED_VARIABLE = /csstools/;
const ROOT_SELECTOR = /^(:root|html)$/;
// Left at HEAD while compiling the base: they do not change the CSS, and the
// asset processor refuses to build when the lockfile and node_modules differ
const KEEP = /^(css_variable_migration\/|package\.json$|pnpm-lock\.yaml$)/;

const { values: options } = parseArgs({
  options: {
    base: { type: "string" },
    "no-compile": { type: "boolean", default: false },
  },
});

const git = (...args) =>
  execFileSync("git", args, { cwd: ROOT, encoding: "utf8" }).trim();

if (!options["no-compile"]) {
  const base = options.base ?? git("merge-base", "HEAD", "origin/main");
  compileBaseAndHead(base);
}

const { renames } = loadMapping();
const browser = await chromium.launch({ channel: "chromium" });
const page = await browser.newPage();
await page.setContent(
  `<div style="position:absolute;left:-9999px;width:1000px;height:500px"><div id="probe"></div></div>`
);

const parsedFiles = new Map();
const sides = ["base", "base-again", "head", "head-again"].filter((side) =>
  existsSync(join(OUTPUT, side, "manifest.json"))
);
const conditions = new Set();
for (const side of sides) {
  const pages = Object.values(readManifest(side)).flatMap(Object.values);
  for (const file of new Set(pages.flat())) {
    parse(side, file).walkAtRules("supports", (at) =>
      conditions.add(at.params)
    );
  }
}
const supported = new Map(
  await page.evaluate(
    (list) => list.map((condition) => [condition, CSS.supports(condition)]),
    [...conditions]
  )
);

const report = {};
for (const profile of Object.keys(readManifest("head"))) {
  report[profile] = await compareProfile(profile);
}
await browser.close();

writeFileSync(join(OUTPUT, "report.json"), JSON.stringify(report, null, 2));
printReport(report);

function compileBaseAndHead(base) {
  if (git("status", "--porcelain", "--", ".", ":!css_variable_migration")) {
    console.error("Commit or stash your changes first.");
    process.exit(1);
  }

  const changes = git("diff", "--name-status", "--no-renames", base, "HEAD")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.split("\t"))
    .filter(([, file]) => !KEEP.test(file));
  const notAdded = changes.filter(([s]) => s !== "A").map(([, f]) => f);
  const notDeleted = changes.filter(([s]) => s !== "D").map(([, f]) => f);

  try {
    if (notAdded.length) {
      git("checkout", base, "--", ...notAdded);
    }
    for (const [status, file] of changes) {
      if (status === "A") {
        rmSync(join(ROOT, file));
      }
    }
    compile("base");
    compile("base-again");
  } finally {
    if (notDeleted.length) {
      git("checkout", "HEAD", "--", ...notDeleted);
    }
    for (const [status, file] of changes) {
      if (status === "D") {
        rmSync(join(ROOT, file), { force: true });
      }
    }
  }

  compile("head");
  compile("head-again");
}

function compile(side) {
  const dir = join(OUTPUT, side);
  rmSync(dir, { recursive: true, force: true });
  console.log(`Compiling ${side}...`);
  const result = spawnSync(
    "bin/rails",
    ["runner", "css_variable_migration/compile.rb", dir],
    { cwd: ROOT, encoding: "utf8" }
  );
  if (result.status !== 0) {
    console.error(result.stderr);
    throw new Error(`Compiling ${side} failed`);
  }
}

function parse(side, file) {
  const key = `${side}/${file}`;
  if (!parsedFiles.has(key)) {
    parsedFiles.set(
      key,
      postcss.parse(readFileSync(join(OUTPUT, side, file), "utf8"))
    );
  }
  return parsedFiles.get(key);
}

function readManifest(side) {
  return JSON.parse(readFileSync(join(OUTPUT, side, "manifest.json"), "utf8"));
}

async function compareProfile(profile) {
  const base = collect("base", profile);
  const head = collect("head", profile);
  const baseAgain = sides.includes("base-again")
    ? collect("base-again", profile)
    : base;
  const headAgain = sides.includes("head-again")
    ? collect("head-again", profile)
    : head;
  const scheme = head.scheme;

  // A random value can repeat by chance, so ignore any rule that differs between runs
  const noisyRules = new Set();
  for (const [run, again] of [
    [base, baseAgain],
    [head, headAgain],
  ]) {
    for (const [where, text] of run.rules) {
      if (again.rules.get(where) !== text) {
        noisyRules.add(where);
      }
    }
  }

  let noisy = 0;
  const declarations = [];
  for (const key of new Set([...base.values.keys(), ...head.values.keys()])) {
    const before = base.values.get(key);
    const after = head.values.get(key);
    if (
      noisyRules.has((before ?? after).where) ||
      before?.value !== baseAgain.values.get(key)?.value ||
      after?.value !== headAgain.values.get(key)?.value
    ) {
      noisy++;
    } else if (before?.value !== after?.value) {
      const { prop, where } = before ?? after;
      declarations.push({ key, prop, where, before, after });
    }
  }

  const variables = [];
  const targets = new Set();
  for (const [name, before] of base.variables) {
    const newName = renames.get(name) ?? name;
    targets.add(newName);
    const after = head.variables.get(newName);
    if (before !== after) {
      variables.push({ name, newName, before, after });
    }
  }
  const added = [...head.variables.keys()].filter((name) => !targets.has(name));

  const canonical = await canonicalize([
    ...declarations.flatMap(({ prop, before, after }) => [
      { prop, value: before?.value, scheme: (before ?? after).scheme },
      { prop, value: after?.value, scheme: (before ?? after).scheme },
    ]),
    ...variables.flatMap(({ before, after }) => [
      { value: before, scheme },
      { value: after, scheme },
    ]),
  ]);

  let i = 0;
  const changed = [];
  for (const d of declarations) {
    const [before, after] = [canonical[i++], canonical[i++]];
    if (before !== after) {
      changed.push({ ...d, before, after });
    }
  }
  const changedVariables = [];
  for (const v of variables) {
    const [before, after] = [canonical[i++], canonical[i++]];
    if (before !== after) {
      changedVariables.push({ ...v, before, after });
    }
  }

  return { declarations: changed, variables: changedVariables, added, noisy };
}

// Resolves each stylesheet once, on the first page that loads it. The :root
// variables are the first page's.
function collect(side, profile) {
  const values = new Map();
  const rules = new Map();
  const compared = new Set();
  let first;
  for (const files of Object.values(readManifest(side)[profile])) {
    const result = collectPage(side, files, compared, values, rules);
    first ??= result;
  }
  return { values, rules, ...first };
}

// Resolves every declaration that applies in Chromium against the page's :root
// variables. A variable that is only set in other scopes resolves to a label,
// because its value depends on where the element sits.
function collectPage(side, files, compared, values, ruleTexts) {
  const roots = new Map();
  const scoped = new Set();
  let scheme = "light";

  const effective = files.map((file) => {
    const root = parse(side, file);
    root.each((node) => {
      if (node.type === "rule" && ROOT_SELECTOR.test(node.selector)) {
        node.each((decl) => {
          if (decl.type !== "decl") {
            return;
          }
          if (decl.prop.startsWith("--")) {
            roots.set(decl.prop, decl.value);
          } else if (decl.prop === "color-scheme") {
            scheme = decl.value.includes("dark") ? "dark" : "light";
          }
        });
      }
    });
    const rules = effectiveRules(root);
    for (const { rule } of rules) {
      if (!ROOT_SELECTOR.test(rule.selector)) {
        rule.each((decl) => {
          if (decl.type === "decl" && decl.prop.startsWith("--")) {
            scoped.add(decl.prop);
          }
        });
      }
    }
    return [file, rules];
  });

  const pageScheme = scheme;
  const resolveRoot = memoizedLookup(roots, (name) =>
    scoped.has(name) ? `<set in a scope: ${name}>` : UNSET
  );

  const scopes = collectScopes(effective);

  for (const [file, rules] of effective) {
    if (compared.has(file)) {
      continue;
    }
    compared.add(file);
    const ordinals = new Map();
    for (const { rule, context } of rules) {
      const where = `${file} ${context.join(" > ")}`;
      ruleTexts.set(where, (ruleTexts.get(where) ?? "") + rule.toString());
      const locals = localsFor(scopes, context);
      const lookup = locals.size
        ? memoizedLookup(locals, resolveRoot)
        : resolveRoot;

      rule.each((decl) => {
        if (decl.type !== "decl" || decl.prop.startsWith("--")) {
          return;
        }
        const id = `${where} ${decl.prop}`;
        const ordinal = (ordinals.get(id) ?? 0) + 1;
        ordinals.set(id, ordinal);
        const resolved = substitute(decl.value, lookup);
        values.set(`${id} #${ordinal}`, {
          where,
          prop: decl.prop,
          value: resolved === UNSET ? "<invalid>" : resolved,
          scheme: pageScheme,
        });
      });
    }
  }

  const variables = new Map();
  for (const name of roots.keys()) {
    if (!IGNORED_VARIABLE.test(name)) {
      const value = resolveRoot(name);
      variables.set(name, value === UNSET ? "<invalid>" : value);
    }
  }

  return { variables, scheme: pageScheme };
}

// Variables set by a rule reach the same elements and their descendants, so a
// rule picks them up from every single selector its own selector starts with
function collectScopes(effective) {
  const scopes = new Map();
  for (const [, rules] of effective) {
    for (const { rule, context } of rules) {
      const selector = context.at(-1);
      const atRules = context.slice(0, -1).join(" > ");
      // Each selector in a list is a scope of its own, and the whole list matches rules with the same list
      const selectors = [
        ...new Set([selector, ...splitSelectorList(selector)]),
      ];
      rule.each((decl) => {
        if (decl.type !== "decl" || !decl.prop.startsWith("--")) {
          return;
        }
        for (const part of selectors) {
          const key = `${atRules} ${part}`;
          if (!scopes.has(key)) {
            const lead = leadingToken(part);
            const list = scopes.get(lead) ?? [];
            const scope = { selector: part, atRules, locals: new Map() };
            list.push(scope);
            scopes.set(lead, list).set(key, scope);
          }
          scopes.get(key).locals.set(decl.prop, decl.value);
        }
      });
    }
  }
  return scopes;
}

function localsFor(scopes, context) {
  const atRules = context.slice(0, -1).join(" > ");
  const parts = splitSelectorList(context.at(-1));
  const startsWith = (text, prefix) =>
    text === prefix ||
    (text.startsWith(prefix) && /^[\s>:.[#]/.test(text.slice(prefix.length)));
  // A one-compound scope reaches every element whose own compound, or an ancestor's, starts with it
  const applies = (scope) =>
    (scope.atRules === "" || scope.atRules === atRules) &&
    !scope.selector.includes(",") &&
    parts.every((part) =>
      /[\s>+~]/.test(scope.selector.trim())
        ? startsWith(part, scope.selector)
        : ancestorsOrSelf(part).some((compound) =>
            startsWith(compound, scope.selector)
          )
    );

  const exact = scopes.get(`${atRules} ${context.at(-1)}`);
  const candidates = parts.flatMap((part) =>
    ancestorsOrSelf(part).flatMap(
      (compound) => scopes.get(leadingToken(compound)) ?? []
    )
  );
  const matching = [...new Set(candidates)]
    .filter(applies)
    .sort((a, b) => a.selector.length - b.selector.length);
  if (exact && !matching.includes(exact)) {
    matching.push(exact);
  }

  const locals = new Map();
  for (const scope of matching) {
    for (const [name, value] of scope.locals) {
      locals.set(name, value);
    }
  }
  return locals;
}

// Compounds that match the subject or one of its ancestors: those followed by a descendant or child combinator, and the last
function ancestorsOrSelf(selector) {
  const compounds = [];
  let depth = 0;
  let current = "";
  for (let i = 0; i < selector.length; i++) {
    const char = selector[i];
    if (char === "(" || char === "[") {
      depth++;
    } else if (char === ")" || char === "]") {
      depth--;
    }
    if (depth === 0 && /[\s>+~]/.test(char)) {
      let j = i;
      while (j < selector.length && /[\s>+~]/.test(selector[j])) {
        j++;
      }
      const combinator = selector.slice(i, j).trim();
      if (current && combinator !== "+" && combinator !== "~") {
        compounds.push(current);
      }
      current = "";
      i = j - 1;
    } else {
      current += char;
    }
  }
  if (current) {
    compounds.push(current);
  }
  return compounds;
}

function leadingToken(selector) {
  return selector.trim().match(/^[.#]?[^\s>+~.:#[,()]*/)[0];
}

function splitSelectorList(selector) {
  const parts = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < selector.length; i++) {
    if (selector[i] === "(") {
      depth++;
    } else if (selector[i] === ")") {
      depth--;
    } else if (selector[i] === "," && depth === 0) {
      parts.push(selector.slice(start, i).trim());
      start = i + 1;
    }
  }
  parts.push(selector.slice(start).trim());
  return parts;
}

// A custom property set to `initial`, or using an unset variable without a
// fallback, is unset; light-dark() polyfills depend on this.
function memoizedLookup(raw, inherited) {
  const cache = new Map();
  const resolving = new Set();
  const lookup = (name) => {
    if (!raw.has(name)) {
      return inherited(name);
    }
    if (cache.has(name)) {
      return cache.get(name);
    }
    if (resolving.has(name)) {
      return UNSET;
    }
    resolving.add(name);
    const value = raw.get(name).trim();
    const resolved = value === "initial" ? UNSET : substitute(value, lookup);
    resolving.delete(name);
    cache.set(name, resolved);
    return resolved;
  };
  return lookup;
}

function substitute(value, lookup) {
  if (!value.includes("var(")) {
    return value;
  }
  const parsed = valueParser(value);
  let invalid = false;
  parsed.walk((node) => {
    if (invalid || node.type !== "function" || node.value !== "var") {
      return;
    }
    const comma = node.nodes.findIndex(
      (n) => n.type === "div" && n.value === ","
    );
    let resolved = lookup(node.nodes[0]?.value);
    if (resolved === UNSET && comma !== -1) {
      resolved = substitute(
        valueParser.stringify(node.nodes.slice(comma + 1)),
        lookup
      );
    }
    if (resolved === UNSET) {
      invalid = true;
    } else {
      node.type = "word";
      node.value = resolved;
    }
    return false;
  });
  return invalid ? UNSET : parsed.toString();
}

// Rules a browser applies: true @supports blocks count as plain CSS, false
// ones are skipped, and only the last @keyframes of each name is used
function effectiveRules(root) {
  const rules = [];
  const lastKeyframes = new Map();

  const visit = (container, context, keyframes) => {
    container.each((node) => {
      if (node.type === "rule") {
        rules.push({
          rule: node,
          context: [...context, node.selector],
          keyframes,
        });
        visit(node, [...context, node.selector], keyframes);
      } else if (node.type !== "atrule") {
        return;
      } else if (node.name === "supports") {
        if (supported.get(node.params)) {
          visit(node, context, keyframes);
        }
      } else if (node.name.endsWith("keyframes")) {
        lastKeyframes.set(`${node.name} ${node.params}`, node);
        visit(node, [...context, `@${node.name} ${node.params}`], node);
      } else {
        visit(node, [...context, `@${node.name} ${node.params}`], keyframes);
      }
    });
  };
  visit(root, []);

  return rules.filter(
    ({ keyframes }) =>
      !keyframes ||
      lastKeyframes.get(`${keyframes.name} ${keyframes.params}`) === keyframes
  );
}

// Computes each value in Chromium and writes colors as 8-bit rgba, so that
// equivalent values such as rgb() with alpha and color-mix() compare equal
async function canonicalize(items) {
  return page.evaluate((list) => {
    const probe = document.getElementById("probe");
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    const COLOR =
      /\b(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|color)\([^()]*\)|#[0-9a-f]{3,8}\b/gi;

    const color = (value) => {
      ctx.clearRect(0, 0, 1, 1);
      ctx.fillStyle = "#000";
      ctx.fillStyle = value;
      ctx.fillRect(0, 0, 1, 1);
      const [r, g, b, a] = ctx.getImageData(0, 0, 1, 1).data;
      return a === 0
        ? "transparent"
        : `rgba(${r}, ${g}, ${b}, ${Math.round(a / 2.55) / 100})`;
    };

    const propFor = (value) =>
      ["color", "width", "box-shadow"].find((p) => CSS.supports(p, value));

    const compute = (property, value, scheme) => {
      probe.style.cssText = `color-scheme: ${scheme}; border-style: solid; outline-style: solid;`;
      probe.style.setProperty(property, value);
      if (!probe.style.getPropertyValue(property)) {
        return null;
      }
      return getComputedStyle(probe)
        .getPropertyValue(property)
        .replace(COLOR, color);
    };

    // Labels for scoped variables are swapped for a placeholder of the same
    // type while computing, then put back
    const LABEL = /<set in a scope: [^>]+>/g;
    const PLACEHOLDERS = [
      (i) => [`rgb(1, 2, ${i})`, `rgba(1, 2, ${i}, 1)`],
      (i) => [`${1000 + i}.5px`, `${1000 + i}.5px`],
    ];

    return list.map(({ prop, value, scheme }) => {
      if (value === undefined || value === "<invalid>") {
        return value ?? "<none>";
      }
      const labels = value.match(LABEL) ?? [];
      for (const placeholder of labels.length ? PLACEHOLDERS : [null]) {
        let probeValue = value;
        labels.forEach((label, i) => {
          probeValue = probeValue.replace(label, placeholder(i)[0]);
        });
        const property = prop ?? propFor(probeValue);
        let result = property && compute(property, probeValue, scheme);
        if (result) {
          labels.forEach((label, i) => {
            result = result.replace(placeholder(i)[1], label);
          });
          return result;
        }
      }
      // A known property with a value Chromium rejects is invalid at computed-value time
      if (!labels.length && prop && CSS.supports(prop, "inherit")) {
        return "<invalid>";
      }
      return value;
    });
  }, items);
}

function printReport(results) {
  for (const [
    profile,
    { declarations, variables, added, noisy },
  ] of Object.entries(results)) {
    console.log(
      `\n${profile}: ${declarations.length} declarations and ${variables.length} variables differ (${noisy} ignored as random)`
    );

    const groups = new Map();
    for (const d of declarations) {
      const label = `${d.prop}: ${d.before} → ${d.after}`;
      groups.set(label, [...(groups.get(label) ?? []), d]);
    }
    for (const [label, items] of [...groups].sort(
      (a, b) => b[1].length - a[1].length
    )) {
      console.log(`  ${truncate(label, 160)}  (${items.length})`);
      for (const item of items.slice(0, 3)) {
        console.log(`      ${truncate(item.where, 150)}`);
      }
    }

    for (const v of variables) {
      const name = v.name === v.newName ? v.name : `${v.name} → ${v.newName}`;
      console.log(`  var ${name}: ${v.before} → ${v.after}`);
    }
    if (added.length) {
      console.log(`  new variables: ${added.join(", ")}`);
    }
  }
  console.log(`\nDetails: ${join(OUTPUT, "report.json")}`);
}

function truncate(text, length) {
  return text.length > length ? `${text.slice(0, length - 1)}…` : text;
}
