import { walkScope } from "../expression-context";

const PLAIN_IDENTIFIER = /^[A-Za-z_$][\w$]*$/;

// Non-identifier names get bracket access so the expression stays valid.
export function propertyAccessor(name) {
  if (PLAIN_IDENTIFIER.test(name)) {
    return `.${name}`;
  }
  const escaped = String(name).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  return `["${escaped}"]`;
}

export function listReferenceProperties(scope, path) {
  const target = walkScope(scope, path);
  if (!target || typeof target !== "object") {
    return [];
  }

  const properties = [];
  for (const name of Object.keys(target)) {
    const value = target[name];
    if (typeof value === "function") {
      continue;
    }
    properties.push({
      name,
      type: Array.isArray(value) ? "array" : typeof value,
    });
  }
  return properties;
}

// Splits at the last top-level accessor, ignoring dots inside strings/subscripts.
function splitLastAccessor(expression) {
  let depth = 0;
  let quote = null;
  let index = -1;
  let isBracket = false;

  for (let i = 0; i < expression.length; i++) {
    const ch = expression[i];
    if (quote) {
      if (ch === "\\") {
        i++;
      } else if (ch === quote) {
        quote = null;
      }
      continue;
    }
    if (ch === '"' || ch === "'") {
      quote = ch;
    } else if (ch === "(" || ch === "[") {
      if (ch === "[" && depth === 0) {
        index = i;
        isBracket = true;
      }
      depth++;
    } else if (ch === ")" || ch === "]") {
      depth--;
    } else if (ch === "." && depth === 0) {
      index = i;
      isBracket = false;
    }
  }

  if (index <= 0) {
    return null;
  }

  const parent = expression.slice(0, index);
  if (!isBracket) {
    return { parent, current: expression.slice(index + 1) };
  }

  // Unquote a bracket key so `current` matches the raw property name.
  let key = expression.slice(index + 1, -1).trim();
  const q = key[0];
  if (q === '"' || q === "'") {
    key = key.slice(1, -1).replace(/\\(.)/g, "$1");
  }
  return { parent, current: key };
}

export function referencePickerData(scope, expression) {
  const inner = (expression || "").trim();
  if (!inner) {
    return null;
  }

  const own = listReferenceProperties(scope, inner);
  if (own.length) {
    return { baseExpr: inner, properties: own, current: null };
  }

  const split = splitLastAccessor(inner);
  if (!split) {
    return null;
  }
  const siblings = listReferenceProperties(scope, split.parent);
  if (siblings.length) {
    return {
      baseExpr: split.parent,
      properties: siblings,
      current: split.current,
    };
  }

  return null;
}
