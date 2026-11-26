// Parts are adapted from @codemirror/lang-liquid 6.3.3,
// Copyright (C) 2018-2023 by Marijn Haverbeke and others, MIT License; see
// LICENSE.

import {
  insertCompletionText,
  pickedCompletion,
  startCompletion,
} from "@codemirror/autocomplete";
import { syntaxTree } from "@codemirror/language";
import { IterMode } from "@lezer/common";
import { i18n } from "discourse-i18n";
import {
  FILTER_ARGUMENTS,
  LOOP_OBJECTS,
  TAG_ARGUMENTS,
  TAG_BLOCKS,
} from "./syntax.js";

// Built per editor rather than at import, so they follow the current locale.
function liquidSections() {
  return {
    tags: { name: i18n("code_editor.liquid.sections.tags"), rank: 1 },
    filters: { name: i18n("code_editor.liquid.sections.filters"), rank: 1 },
  };
}

const LITERALS = [
  "CommentText",
  "InlineComment",
  "NumberLiteral",
  "RawText",
  "StringLiteral",
];

const WORD = /^[\w\u00c0-\uffff-]*$/;

const IDENTIFIER =
  /^[a-z_\u00c0-\uffff](?:[\w\u00c0-\uffff]|-+[\w\u00c0-\uffff])*$/i;

const ARRAY_PROPERTIES = ["first", "last", "size"].map((label) => ({
  label,
  type: "property",
}));

function tagOptions(names, section) {
  const labels = new Set(
    names.flatMap((name) => [name, ...(TAG_BLOCKS[name] ?? [])])
  );

  return [...labels].map((label) => {
    const args = TAG_ARGUMENTS[label];
    return {
      label,
      type: "keyword",
      detail: args,
      apply: args ? `${label} ` : label,
      section,
    };
  });
}

function filterOptions(names, section) {
  return names.map((label) => ({
    label,
    type: "function",
    detail: FILTER_ARGUMENTS[label] || undefined,
    section,
  }));
}

// Names come from templates, so a name like `constructor` must not find a
// built-in.
function dictionary(entries = {}) {
  return Object.assign(Object.create(null), entries);
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

// Picking an object leaves the cursor after its dot, ready for a property. A
// key that is not a name is read with a subscript in place of the dot; null
// means it cannot be written at all.
function keyApply(label, record) {
  let text = label;
  const subscript = !IDENTIFIER.test(label);
  if (subscript) {
    const quote = label.includes('"') ? "'" : '"';
    if (label.includes(quote)) {
      return null;
    }
    text = `[${quote}${label}${quote}]`;
  } else if (!record) {
    return undefined;
  }
  if (record) {
    text += ".";
  }

  return (view, completion, from, to) => {
    const dot = subscript && view.state.sliceDoc(from - 1, from) === ".";
    view.dispatch({
      ...insertCompletionText(view.state, text, dot ? from - 1 : from, to),
      annotations: pickedCompletion.of(completion),
    });
    if (record) {
      startCompletion(view);
    }
  };
}

const DECLARATIONS = ["assign", "capture", "for", "tablerow"];

function declares(node) {
  return (
    DECLARATIONS.includes(node.prevSibling?.name) ||
    (node.parent?.name === "AssignmentExpression" && !node.prevSibling)
  );
}

function findContext(context) {
  const { state, pos } = context;
  const node = syntaxTree(state)
    .resolveInner(pos, -1)
    .enterUnfinishedNodesBefore(pos);
  if (LITERALS.includes(node.name)) {
    return null;
  }

  const before = node.childBefore(pos)?.name || node.name;

  if (node.name === "FilterName") {
    return { type: "filter", from: node.from };
  }
  if (before === "|") {
    return { type: "filter", from: pos };
  }
  // A complete standard keyword parses as its own node rather than a name.
  if (
    node.name === "TagName" ||
    (node.parent?.name === "Tag" && node.prevSibling?.name === "{%")
  ) {
    return { type: "tag", from: node.from };
  }
  if (before === "{%") {
    return { type: "tag", from: pos };
  }
  if (node.name === "PropertyName" && node.parent.name === "MemberExpression") {
    return { type: "property", from: node.from, target: node.parent, node };
  }
  if (node.name === "." && node.parent.name === "MemberExpression") {
    return { type: "property", from: pos, target: node.parent, node };
  }
  if (node.name === "MemberExpression" && before === ".") {
    return { type: "property", from: pos, target: node, node };
  }
  if (node.name === "VariableName") {
    return declares(node)
      ? null
      : { type: "expression", from: node.from, node };
  }
  if (DECLARATIONS.includes(before)) {
    return null;
  }

  const word = context.matchBefore(/[\w\u00c0-\uffff][\w\u00c0-\uffff-]*$/);
  if (word) {
    return { type: "expression", from: word.from, node };
  }

  return context.explicit ? { type: "expression", from: pos, node } : null;
}

function pathOf(state, node) {
  const path = [];

  for (;;) {
    if (!node) {
      return null;
    }

    if (["VariableName", "forloop", "tablerowloop"].includes(node.name)) {
      path.unshift(state.sliceDoc(node.from, node.to));
      return path;
    }

    if (node.name === "MemberExpression") {
      const name = node.getChild("PropertyName");
      if (name) {
        path.unshift(state.sliceDoc(name.from, name.to));
      }
      node = node.getChild("Expression");
    } else if (node.name === "SubscriptExpression") {
      const [object, index] = node.getChildren("Expression");
      if (index?.name === "StringLiteral") {
        path.unshift(state.sliceDoc(index.from + 1, index.to - 1));
      } else if (index?.name === "NumberLiteral") {
        path.unshift(state.sliceDoc(index.from, index.to));
      } else {
        path.unshift("[]");
      }
      node = object;
    } else {
      return null;
    }
  }
}

// The value at `path` and the path it has in the root scope, where a loop
// variable reads as its collection and every list element as "[]". Lists in
// the context are examples, so any element stands in for the rest.
function resolve(scope, aliases, path) {
  const [name, ...keys] = path;
  if (!(name in scope)) {
    return undefined;
  }

  let value = scope[name];
  const canonical = [...(aliases[name] ?? [name])];
  for (const key of keys) {
    if (Array.isArray(value)) {
      if (key === "size") {
        value = value.length;
        canonical.push(key);
        continue;
      }
      if (key === "last") {
        value = value.at(-1);
      } else if (key === "first" || key === "[]" || /^\d+$/.test(key)) {
        value = value[key] ?? value[0];
      } else {
        return undefined;
      }
      canonical.push("[]");
    } else if (isRecord(value) && Object.hasOwn(value, key)) {
      value = value[key];
      canonical.push(key);
    } else {
      return undefined;
    }
  }

  return { value, path: canonical };
}

// What a template sets but the example cannot show, such as a loop over a
// range or a filtered assign. It completes as a name without properties.
const UNKNOWN = Symbol("unknown");

function bind(names, name, value, path) {
  names.scope[name] = value;
  names.aliases[name] = path || null;
}

// `names` with the variables of each loop around `node` bound to an element
// of its collection.
function withLoops(state, names, node) {
  const loops = [];
  for (let parent = node; parent; parent = parent.parent) {
    const loop = LOOP_OBJECTS[parent.name];
    const tag = parent.firstChild;
    if (loop && tag?.name === "Tag" && node.from >= tag.to) {
      loops.unshift({ loop, tag });
    }
  }

  if (!loops.length) {
    return names;
  }

  // Loop bindings shadow a null-prototype scope without copying every prior
  // assignment each time an assign inside the loop is resolved.
  const result = {
    scope: Object.create(names.scope),
    aliases: Object.create(names.aliases),
  };
  for (const { loop, tag } of loops) {
    const binding = tag.getChild("VariableName");
    const collection = tag.getChild("in")?.nextSibling;
    if (!binding || !collection) {
      continue;
    }

    const path = pathOf(state, collection);
    const found = path && resolve(result.scope, result.aliases, path);
    const list = Array.isArray(found?.value) ? found.value : [];
    bind(
      result,
      state.sliceDoc(binding.from, binding.to),
      list[0] ?? UNKNOWN,
      found && [...found.path, "[]"]
    );
    bind(result, loop.name, loop.value, null);
  }

  return result;
}

// The root scope with what `assign` and `capture` set before `pos`, from the
// end of an assign tag or of a capture block. An assign of a path reads as
// that path.
function withAssigns(state, root, pos) {
  const names = { scope: dictionary(root), aliases: dictionary() };

  syntaxTree(state).iterate({
    to: pos,
    mode: IterMode.IgnoreMounts,
    enter: ({ name, node, to }) => {
      // A tag still being typed ends at the cursor without being closed.
      const closed = node.lastChild?.name === "%}" || to < pos;
      if (to > pos) {
        return;
      }

      if (name === "CaptureDirective" && node.lastChild?.name === "EndTag") {
        const target = node.firstChild?.getChild("VariableName");
        if (target) {
          bind(names, state.sliceDoc(target.from, target.to), "", null);
        }
      } else if (name === "Tag" && closed && node.getChild("assign")) {
        const assignment = node.getChild("AssignmentExpression");
        const target = assignment?.firstChild;
        const value = assignment?.lastChild;
        if (target?.name !== "VariableName" || value === target) {
          return;
        }

        const at = withLoops(state, names, node);
        const path = !node.getChild("Filter") && pathOf(state, value);
        const found = path && resolve(at.scope, at.aliases, path);
        bind(
          names,
          state.sliceDoc(target.from, target.to),
          found?.value ?? UNKNOWN,
          found?.path
        );
      }
    },
  });

  return names;
}

function scopeAt(state, node, pos, root) {
  const names = withAssigns(state, root, pos);
  const scoped = withLoops(state, names, node);
  return {
    scope: Object.assign(names.scope, scoped.scope),
    aliases: scoped.aliases,
  };
}

function contextOptions(object, { base, aliases = dictionary() }, describe) {
  const options = [];

  for (const [label, value] of Object.entries(object)) {
    // Only a property can be read with a subscript.
    if (value === undefined || (!base && !IDENTIFIER.test(label))) {
      continue;
    }
    const known = value === UNKNOWN ? undefined : value;
    const apply = keyApply(label, isRecord(known));
    if (apply === null) {
      continue;
    }

    const extra = describe?.(
      base ? [...base, label] : (aliases[label] ?? [label]),
      known,
      { variable: !base }
    );
    if (extra === null) {
      continue;
    }

    const option = {
      label,
      type: base ? "property" : "variable",
      ...(apply && { apply }),
      detail: extra?.detail,
      info: extra?.info,
      boost: extra?.boost,
      section: extra?.section,
    };
    options.push(option);
  }

  return options;
}

/**
 * Completes Liquid tags, filters, and the paths of an example render context.
 *
 * @param {import("discourse/lib/liquid-language").LiquidOptions} [options]
 */
export function liquidCompletionSource(options = {}) {
  const sections = liquidSections();
  const tags = tagOptions(
    options.tags ?? Object.keys(TAG_BLOCKS),
    sections.tags
  );
  const filters = filterOptions(
    options.filters ?? Object.keys(FILTER_ARGUMENTS),
    sections.filters
  );

  return (context) => {
    const cx = findContext(context);
    if (!cx) {
      return null;
    }

    let result;
    if (cx.type === "tag") {
      result = tags;
    } else if (cx.type === "filter") {
      result = filters;
    } else {
      const root =
        (typeof options.scope === "function"
          ? options.scope()
          : options.scope) ?? {};
      const { scope, aliases } = scopeAt(
        context.state,
        cx.node,
        context.pos,
        root
      );

      if (cx.type === "expression") {
        result = contextOptions(scope, { aliases }, options.describe);
      } else {
        const path = pathOf(context.state, cx.target.getChild("Expression"));
        const found = path && resolve(scope, aliases, path);
        if (Array.isArray(found?.value)) {
          result = ARRAY_PROPERTIES;
        } else if (isRecord(found?.value)) {
          result = contextOptions(
            found.value,
            { base: found.path },
            options.describe
          );
        }
      }
    }

    return result?.length
      ? { from: cx.from, options: result, validFor: WORD }
      : null;
  };
}
