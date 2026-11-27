import { i18n } from "discourse-i18n";
import {
  buildScopeFromFields,
  buildSiteSettingsScope,
  buildVarsScope,
  walkScope,
} from "./expression-context.js";

const EXECUTION = Object.freeze({ id: 0, workflow_id: 0, workflow_name: "" });

// What the template node renders. `render` and `include` stay out: the
// server parses with no file system.
export const TEMPLATE_TAGS = [
  "assign",
  "break",
  "capture",
  "case",
  "comment",
  "continue",
  "cycle",
  "decrement",
  "echo",
  "for",
  "if",
  "ifchanged",
  "increment",
  "liquid",
  "raw",
  "tablerow",
  "unless",
];

// Surfaced first, since they are what a template is usually built around.
const BOOSTED_ROOTS = { item: 10, items: 10, item_index: 5 };

function valueDetail(value) {
  // The editor cannot always tell what a template set.
  if (value === undefined) {
    return undefined;
  }
  if (Array.isArray(value)) {
    return "array";
  }
  if (value === null) {
    return "null";
  }
  return typeof value;
}

// A loop variable ranks just ahead of the collection it walks.
function variableBoost(path) {
  if (path.length === 1) {
    return BOOSTED_ROOTS[path[0]];
  }
  const collection = path.length === 2 && path[1] === "[]" && path[0];
  return BOOSTED_ROOTS[collection] && BOOSTED_ROOTS[collection] + 1;
}

/** How the editor lists a path of the render context. */
export function describeScopePath(path, value, { variable }) {
  const boost = variable ? variableBoost(path) : undefined;
  let section = "properties";
  if (variable) {
    section = boost ? "recommended" : "metadata";
  }

  return {
    detail: valueDetail(value),
    boost,
    section: {
      name: i18n(`discourse_workflows.liquid_editor.sections.${section}`),
      rank: { recommended: 0, properties: 2, metadata: 3 }[section],
    },
  };
}

// Mirrors the server's `template_item`.
function buildTemplateItem(json) {
  return { ...json, item: { json }, item_index: 1 };
}

/**
 * An exemplar of the render context, with placeholder values of the right
 * shape, for resolving completions.
 */
export function buildLiquidScope({
  branchFields = [],
  siteSettings,
  globalVars,
  perItem = false,
} = {}) {
  const inputs = Array.from(branchFields, (fields) =>
    fields ? [buildTemplateItem(buildScopeFromFields(fields))] : []
  );
  const templateItem =
    inputs[0]?.[0] ?? buildTemplateItem(buildScopeFromFields([]));

  const base = {
    items: [templateItem],
    inputs,
    items_count: 0,
    vars: buildVarsScope(globalVars),
    workflow: { id: "", name: "", active: true },
    execution: { ...EXECUTION },
    site_settings: buildSiteSettingsScope(siteSettings),
  };

  if (!perItem) {
    return base;
  }

  // Shared keys win on collision, as on the server.
  return { ...templateItem, ...base, item: templateItem, item_index: 1 };
}

const ENVIRONMENT_ALIASES = {
  $execution: "execution",
  $site_settings: "site_settings",
  $vars: "vars",
};

// Paths only: `$json.a + 1` has no Liquid equivalent.
const PATH_ROOT_RE = /^\$?[A-Za-z_]\w*/;
const PATH_REST_RE =
  /^(?:\.[A-Za-z_]\w*|\[\d+\]|\["(?:[^"\\]|\\.)*"\]|\['(?:[^'\\]|\\.)*'\])*$/;

// Innermost loop over `collection` in `loops`.
function itemLoop(loops, collection) {
  const paths = collection === "items" ? ["items", "inputs[0]"] : [collection];
  const shadowedNames = new Set();
  for (let i = loops.length - 1; i >= 0; i--) {
    const loop = loops[i];
    if (paths.includes(loop.path)) {
      // Liquid exposes iteration indexes, but not the source offset.
      const forloop = loop.offset
        ? null
        : `forloop${".parentloop".repeat(loops.length - i - 1)}.${
            loop.reversed ? "rindex0" : "index0"
          }`;
      return {
        alias: shadowedNames.has(loop.name) ? null : loop.name,
        path: loop.path,
        forloop,
      };
    }
    shadowedNames.add(loop.name);
  }
  return null;
}

/**
 * The current item of `collection` in `loops`: a loop alias, an index back into
 * the collection, or the mode's default outside any loop. Other branches pair
 * with the primary loop's index.
 */
export function itemPrefix(
  loops,
  { perItem = false, collection = "items" } = {}
) {
  const loop = itemLoop(loops, collection);
  if (loop) {
    if (loop.alias) {
      return loop.alias;
    }
    return loop.forloop ? `${loop.path}[${loop.forloop}]` : null;
  }

  if (collection !== "items") {
    const primary = itemLoop(loops, "items");
    if (primary) {
      return primary.forloop ? `${collection}[${primary.forloop}]` : null;
    }
  }

  if (!perItem) {
    return `${collection}[0]`;
  }
  // Per-item mode walks the primary input only.
  return collection === "items" ? "item" : null;
}

/**
 * The 0-based index of the current primary item, or null outside a
 * loop over it.
 */
export function itemIndex(loops) {
  return itemLoop(loops, "items")?.forloop ?? null;
}

function restAfterPrefix(id, prefix) {
  if (!prefix || !id.startsWith(prefix)) {
    return null;
  }
  const rest = id.slice(prefix.length);
  return rest === "" || rest.startsWith(".") || rest.startsWith("[")
    ? rest
    : null;
}

/**
 * A dragged field's path as the template can render it in `loops`, or null for
 * a source it cannot reach. `secondaryInputs` lists the other connected
 * branches as `{ prefix, inputIndex }`.
 */
export function liquidPathForVariable(
  id,
  loops,
  { perItem = false, secondaryInputs = [] } = {}
) {
  if (!id) {
    return null;
  }

  for (const { prefix, inputIndex } of secondaryInputs) {
    const rest = restAfterPrefix(id, prefix);
    if (rest === null) {
      continue;
    }
    const itemPath = itemPrefix(loops, {
      perItem,
      collection: `inputs[${inputIndex}]`,
    });
    return itemPath && PATH_REST_RE.test(rest) ? `${itemPath}${rest}` : null;
  }

  const root = PATH_ROOT_RE.exec(id)?.[0];
  if (!root) {
    return null;
  }
  const rest = id.slice(root.length);
  if (!PATH_REST_RE.test(rest)) {
    return null;
  }

  if (!root.startsWith("$") || root === "$json") {
    const itemPath = itemPrefix(loops, { perItem });
    if (!itemPath) {
      return null;
    }
    return root === "$json" ? `${itemPath}${rest}` : `${itemPath}.${id}`;
  }
  if (root === "$itemIndex") {
    return rest ? null : itemIndex(loops);
  }

  const alias = ENVIRONMENT_ALIASES[root];
  if (!alias) {
    return null;
  }
  const path = `${alias}${rest}`;
  if (
    root === "$execution" &&
    walkScope({ execution: EXECUTION }, path) === undefined
  ) {
    return null;
  }
  return path;
}
