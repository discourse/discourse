import {
  buildExecutionScope,
  buildScopeFromFields,
  buildSiteSettingsScope,
  buildVarsScope,
  walkScope,
} from "./expression-context.js";

// Standard Liquid filters, with the arguments each one accepts.
export const LIQUID_FILTERS = [
  ["abs", "()"],
  ["append", "(string)"],
  ["at_least", "(number)"],
  ["at_most", "(number)"],
  ["capitalize", "()"],
  ["ceil", "()"],
  ["compact", "()"],
  ["concat", "(array)"],
  ["date", "(format)"],
  ["default", "(value)"],
  ["divided_by", "(number)"],
  ["downcase", "()"],
  ["escape", "()"],
  ["escape_once", "()"],
  ["first", "()"],
  ["floor", "()"],
  ["join", "(separator)"],
  ["last", "()"],
  ["lstrip", "()"],
  ["map", "(key)"],
  ["minus", "(number)"],
  ["modulo", "(number)"],
  ["newline_to_br", "()"],
  ["plus", "(number)"],
  ["prepend", "(string)"],
  ["remove", "(string)"],
  ["remove_first", "(string)"],
  ["replace", "(from, to)"],
  ["replace_first", "(from, to)"],
  ["reverse", "()"],
  ["round", "(precision)"],
  ["rstrip", "()"],
  ["size", "()"],
  ["slice", "(offset, length)"],
  ["sort", "(key)"],
  ["sort_natural", "(key)"],
  ["split", "(separator)"],
  ["strip", "()"],
  ["strip_html", "()"],
  ["strip_newlines", "()"],
  ["sum", "(key)"],
  ["times", "(number)"],
  ["truncate", "(length)"],
  ["truncatewords", "(count)"],
  ["uniq", "()"],
  ["upcase", "()"],
  ["url_decode", "()"],
  ["url_encode", "()"],
  ["where", "(key, value)"],
];

const FORLOOP = Object.freeze({
  first: false,
  index: 0,
  index0: 0,
  last: false,
  length: 0,
  rindex: 0,
  rindex0: 0,
});

// Mirrors the server's per-item hash: the input's json fields, plus the raw
// wrapper under `item` and a 1-based `item_index`.
function buildTemplateItem(json) {
  return { ...json, item: { json }, item_index: 1 };
}

/**
 * Builds an exemplar of the Liquid render context, used to resolve property
 * completions. Values are placeholders of the right shape, not real data.
 */
export function buildLiquidScope({
  inputFields = [],
  branchFields = [],
  siteSettings,
  globalVars,
  nodes,
  perItem = false,
} = {}) {
  const templateItem = buildTemplateItem(buildScopeFromFields(inputFields));
  const execution = buildExecutionScope(nodes);

  const base = {
    items: [templateItem],
    inputs: Array.from(branchFields, (fields) =>
      fields ? [buildTemplateItem(buildScopeFromFields(fields))] : []
    ),
    items_count: 0,
    vars: buildVarsScope(globalVars),
    workflow: { id: "", name: "", active: true },
    execution: {
      id: execution.id,
      workflow_id: execution.workflow_id,
      workflow_name: execution.workflow_name,
    },
    site_settings: buildSiteSettingsScope(siteSettings),
  };

  if (!perItem) {
    return base;
  }

  // Per-item mode merges the current item's fields into the root, with the
  // shared keys winning on collision — the same order the server uses.
  return { ...templateItem, ...base, item: templateItem, item_index: 1 };
}

const LOOP_TAG_RE =
  /\{%-?\s*(for|endfor|comment|endcomment|raw|endraw)\b([^%]*)%\}/g;
// `reversed` only counts right after the collection, as in Liquid itself.
const FOR_BINDING_RE = /^\s*([\w-]+)\s+in\s+([\w.[\]'"-]+)(\s+reversed\b)?/;

/**
 * The `for` loops enclosing `pos`, outermost first, as `{ name, path }` pairs.
 * Unparseable loops are kept as null so nesting stays aligned.
 */
export function enclosingLoopsAt(text, pos) {
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

    const loop = { name: binding[1], path: binding[2] };
    const options = match[2].slice(binding[0].length);
    if (/\boffset\s*:/.test(options)) {
      loop.index = null;
    } else if (binding[3]) {
      loop.index = "rindex0";
    }
    stack.push(loop);
  }

  return stack;
}

/**
 * Resolves the loop variables in scope at `pos`, so `{% for item in items %}`
 * binds `item` to an element of `items`.
 */
export function loopBindingsAt(scope, text, pos) {
  const bindings = {};
  for (const entry of enclosingLoopsAt(text, pos)) {
    if (!entry) {
      continue;
    }
    // Each loop resolves against the ones enclosing it, so a nested loop can
    // iterate over a collection reached through the outer loop's variable.
    const collection = walkScope({ ...scope, ...bindings }, entry.path);
    bindings[entry.name] = Array.isArray(collection) ? collection[0] : {};
    bindings.forloop = FORLOOP;
  }

  return bindings;
}

// Environment symbols the render context exposes under a different name.
const ENVIRONMENT_ALIASES = {
  $execution: "execution",
  $site_settings: "site_settings",
  $vars: "vars",
};

// A dotted or bracketed path and nothing else: an expression such as
// `$json.a + 1` has no Liquid equivalent.
const PATH_ROOT_RE = /^\$?[A-Za-z_]\w*/;
const PATH_REST_RE =
  /^(?:\.[A-Za-z_]\w*|\[\d+\]|\["(?:[^"\\]|\\.)*"\]|\['(?:[^'\\]|\\.)*'\])*$/;

// The innermost loop over `collection` enclosing `pos`: its alias when no
// inner loop shadows it, and the forloop index that addresses the collection.
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
      const forloop =
        loop.index === null
          ? null
          : `forloop${".parentloop".repeat(loops.length - i - 1)}.${
              loop.index || "index0"
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
 * Resolves the current item of `collection` at `pos`: a loop alias, an index
 * back into the collection, or the mode's default outside any loop. Another
 * branch pairs with the primary loop's index, since items line up across
 * inputs.
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
 * loop over it: `item_index` is 1-based, so it is no substitute.
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
 * Rewrites a dragged field's expression path as its Liquid equivalent, or
 * returns null for a source the render context cannot reach.
 *
 * `itemPrefix` addresses the primary input's current item and `itemIndex`
 * its 0-based index, both resolved at the drop position. `inputs` lists the
 * other connected branches as `{ prefix, itemPrefix }`, and `scope` is the
 * render context exemplar.
 */
export function liquidPathForVariable(
  id,
  { itemPrefix = null, itemIndex = null, inputs = [], scope = null } = {}
) {
  if (!id) {
    return null;
  }

  for (const input of inputs) {
    const rest = restAfterPrefix(id, input.prefix);
    if (rest !== null) {
      return input.itemPrefix && PATH_REST_RE.test(rest)
        ? `${input.itemPrefix}${rest}`
        : null;
    }
  }

  const root = PATH_ROOT_RE.exec(id)?.[0];
  if (!root) {
    return null;
  }
  const rest = id.slice(root.length);
  if (!PATH_REST_RE.test(rest)) {
    return null;
  }

  if (!root.startsWith("$")) {
    return itemPrefix ? `${itemPrefix}.${id}` : null;
  }
  if (root === "$json") {
    return itemPrefix ? `${itemPrefix}${rest}` : null;
  }
  if (root === "$itemIndex") {
    return rest ? null : itemIndex;
  }

  const alias = ENVIRONMENT_ALIASES[root];
  if (!alias) {
    return null;
  }
  const path = `${alias}${rest}`;
  // Execution data is a closed shape the exemplar knows in full; variables
  // and settings are not, so only their roots are checked.
  if (root === "$execution" && scope && walkScope(scope, path) === undefined) {
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
