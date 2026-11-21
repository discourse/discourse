import {
  buildScopeFromFields,
  buildSiteSettingsScope,
  buildVarsScope,
  walkScope,
} from "./expression-context.js";

const FORLOOP = Object.freeze({
  first: false,
  index: 0,
  index0: 0,
  last: false,
  length: 0,
  rindex: 0,
  rindex0: 0,
});

const EXECUTION = Object.freeze({ id: 0, workflow_id: 0, workflow_name: "" });

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

const LOOP_TAG_RE =
  /\{%-?\s*(for|endfor|comment|endcomment|raw|endraw)\b([^%]*)%\}/g;
// `reversed` only counts right after the collection, as in Liquid itself.
const FOR_BINDING_RE = /^\s*([\w-]+)\s+in\s+([\w.[\]'"-]+)(\s+reversed\b)?/;

// The `for` loops enclosing `pos`, outermost first. Unparseable loops stay
// as null so nesting depth is preserved.
function enclosingLoopsAt(text, pos) {
  const before = text.slice(0, pos);
  const stack = [];
  let ignoredBlock = null;
  let commentDepth = 0;

  LOOP_TAG_RE.lastIndex = 0;
  let match;
  while ((match = LOOP_TAG_RE.exec(before))) {
    const tag = match[1];
    if (ignoredBlock) {
      if (ignoredBlock === "comment" && tag === "comment") {
        commentDepth++;
      } else if (tag === `end${ignoredBlock}`) {
        if (commentDepth > 0) {
          commentDepth--;
        } else {
          ignoredBlock = null;
        }
      }
      continue;
    }

    if (tag === "comment" || tag === "raw") {
      ignoredBlock = tag;
      continue;
    }

    if (tag === "endfor") {
      stack.pop();
      continue;
    }

    if (tag !== "for") {
      continue;
    }

    const binding = FOR_BINDING_RE.exec(match[2]);
    if (!binding) {
      stack.push(null);
      continue;
    }

    stack.push({
      name: binding[1],
      path: binding[2],
      reversed: Boolean(binding[3]),
      offset: /\boffset\s*:/.test(match[2].slice(binding[0].length)),
    });
  }

  return stack;
}

/**
 * The loop variables in scope at `pos`, each bound to an element of its
 * collection.
 */
export function loopBindingsAt(scope, text, pos) {
  const bindings = {};
  for (const entry of enclosingLoopsAt(text, pos)) {
    if (!entry) {
      continue;
    }
    const collection = walkScope({ ...scope, ...bindings }, entry.path);
    bindings[entry.name] = Array.isArray(collection) ? collection[0] : {};
    bindings.forloop = FORLOOP;
  }

  return bindings;
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

// Innermost loop over `collection` at `pos`.
function itemLoopAt(text, pos, collection) {
  const loops = enclosingLoopsAt(text, pos);
  const paths = collection === "items" ? ["items", "inputs[0]"] : [collection];
  const shadowedNames = new Set();
  for (let i = loops.length - 1; i >= 0; i--) {
    const loop = loops[i];
    if (!loop) {
      continue;
    }
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
 * The current item of `collection` at `pos`: a loop alias, an index back into
 * the collection, or the mode's default outside any loop. Other branches pair
 * with the primary loop's index.
 */
export function itemPrefixAt(
  text,
  pos,
  { perItem = false, collection = "items" } = {}
) {
  const loop = itemLoopAt(text, pos, collection);
  if (loop) {
    if (loop.alias) {
      return loop.alias;
    }
    return loop.forloop ? `${loop.path}[${loop.forloop}]` : null;
  }

  if (collection !== "items") {
    const primary = itemLoopAt(text, pos, "items");
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
 * The 0-based index of the current primary item at `pos`, or null outside a
 * loop over it.
 */
export function itemIndexAt(text, pos) {
  return itemLoopAt(text, pos, "items")?.forloop ?? null;
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
 * A dragged field's path as the template can render it at `pos`, or null for
 * a source it cannot reach. `secondaryInputs` lists the other connected
 * branches as `{ prefix, inputIndex }`.
 */
export function liquidPathForVariable(
  id,
  text,
  pos,
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
    const itemPrefix = itemPrefixAt(text, pos, {
      perItem,
      collection: `inputs[${inputIndex}]`,
    });
    return itemPrefix && PATH_REST_RE.test(rest)
      ? `${itemPrefix}${rest}`
      : null;
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
    const itemPrefix = itemPrefixAt(text, pos, { perItem });
    if (!itemPrefix) {
      return null;
    }
    return root === "$json" ? `${itemPrefix}${rest}` : `${itemPrefix}.${id}`;
  }
  if (root === "$itemIndex") {
    return rest ? null : itemIndexAt(text, pos);
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

/**
 * Locates the unclosed `{{` or `{%` that `pos` sits inside, or null when the
 * position is in plain template text.
 */
export function openDelimiterAt(text, pos) {
  const before = text.slice(0, pos);
  const outputOpen = before.lastIndexOf("{{");
  const tagOpen = before.lastIndexOf("{%");
  const open = Math.max(outputOpen, tagOpen);

  if (open === -1) {
    return null;
  }

  const delimiter = open === outputOpen ? "output" : "tag";
  const close = delimiter === "output" ? "}}" : "%}";

  if (before.indexOf(close, open) !== -1) {
    return null;
  }

  return { delimiter, open };
}

const WORD_RE = /[\w.[\]'"-]*$/;

/**
 * Describes what the cursor is completing inside a Liquid delimiter: a tag
 * name, a filter after `|`, a property after `.`, or a bare identifier.
 */
export function analyzeLiquidAt(text, pos) {
  const context = openDelimiterAt(text, pos);
  if (!context) {
    return null;
  }

  const { delimiter, open } = context;
  // Whitespace control (`{%-`) is part of the delimiter, not of the tag name.
  const inner = text.slice(open + 2, pos).replace(/^-/, "");
  const partial = WORD_RE.exec(inner)[0];
  const from = pos - partial.length;
  const preceding = inner.slice(0, inner.length - partial.length).trimEnd();

  if (delimiter === "tag" && preceding === "") {
    return { kind: "tagName", delimiter, partial, from };
  }

  if (preceding.endsWith("|")) {
    return { kind: "filter", delimiter, partial, from };
  }

  const lastDot = partial.lastIndexOf(".");
  if (lastDot !== -1) {
    return {
      kind: "property",
      delimiter,
      object: partial.slice(0, lastDot),
      partial: partial.slice(lastDot + 1),
      from: from + lastDot + 1,
    };
  }

  return { kind: "root", delimiter, partial, from };
}
