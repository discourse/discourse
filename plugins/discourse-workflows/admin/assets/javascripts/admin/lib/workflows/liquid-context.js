import {
  buildExecutionScope,
  buildScopeFromFields,
  buildSiteSettingsScope,
  buildVarsScope,
  walkScope,
} from "./expression-context";

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

// Tags offered when a `{%` has just been opened. Closing tags are completed
// too, so `{% endf` finishes even though it opens nothing.
export const LIQUID_TAGS = [
  ["assign", "name = value"],
  ["break", ""],
  ["capture", "name"],
  ["case", "value"],
  ["comment", ""],
  ["continue", ""],
  ["cycle", "a, b"],
  ["decrement", "name"],
  ["echo", "value"],
  ["else", ""],
  ["elsif", "condition"],
  ["endcapture", ""],
  ["endcase", ""],
  ["endcomment", ""],
  ["endfor", ""],
  ["endif", ""],
  ["endraw", ""],
  ["endtablerow", ""],
  ["endunless", ""],
  ["for", "item in collection"],
  ["if", "condition"],
  ["increment", "name"],
  ["liquid", ""],
  ["raw", ""],
  ["tablerow", "item in collection"],
  ["unless", "condition"],
  ["when", "value"],
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
  workflowVars,
  nodes,
  perItem = false,
} = {}) {
  const templateItem = buildTemplateItem(buildScopeFromFields(inputFields));
  const execution = buildExecutionScope(nodes);

  const base = {
    items: [templateItem],
    inputs: branchFields.map((fields) => [
      buildTemplateItem(buildScopeFromFields(fields)),
    ]),
    items_count: 0,
    vars: buildVarsScope(workflowVars),
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

const LOOP_TAG_RE = /\{%-?\s*(for|endfor)\b([^%]*)%\}/g;
const FOR_BINDING_RE = /^\s*([\w-]+)\s+in\s+([\w.[\]'"-]+)/;

/**
 * The `for` loops enclosing `pos`, outermost first, as `{ name, path }` pairs.
 * Unparseable loops are kept as null so nesting stays aligned.
 */
export function enclosingLoopsAt(text, pos) {
  const before = text.slice(0, pos);
  const stack = [];

  LOOP_TAG_RE.lastIndex = 0;
  let match;
  while ((match = LOOP_TAG_RE.exec(before))) {
    if (match[1] === "endfor") {
      stack.pop();
      continue;
    }

    const binding = FOR_BINDING_RE.exec(match[2]);
    stack.push(binding ? { name: binding[1], path: binding[2] } : null);
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
  $itemIndex: "item_index",
  $site_settings: "site_settings",
  $vars: "vars",
};

/**
 * The path an item's fields are reached through at `pos`: the innermost loop
 * variable if one is iterating, otherwise how the mode addresses the current
 * item.
 */
export function itemPrefixAt(text, pos, { perItem = false } = {}) {
  const loops = enclosingLoopsAt(text, pos);
  for (let i = loops.length - 1; i >= 0; i--) {
    if (loops[i]) {
      return loops[i].name;
    }
  }
  return perItem ? "item" : "items[0]";
}

/**
 * Rewrites a dragged field's expression path as its Liquid equivalent, or
 * returns null for a source the render context cannot reach — another node's
 * output, say, which Liquid templates have no access to.
 */
export function liquidPathForVariable(id, itemPrefix) {
  if (!id) {
    return null;
  }

  if (!id.startsWith("$")) {
    return `${itemPrefix}.${id}`;
  }

  const [root] = id.split(/[.[]/, 1);
  const rest = id.slice(root.length);

  if (root === "$json") {
    return rest ? `${itemPrefix}${rest}` : itemPrefix;
  }

  const alias = ENVIRONMENT_ALIASES[root];
  return alias ? `${alias}${rest}` : null;
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
