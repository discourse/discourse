import { i18n } from "discourse-i18n";

function sectionHeader(name) {
  return () => {
    const header = document.createElement("div");
    header.className = "cm-expr-section-header";
    header.textContent = name;
    return header;
  };
}

export function section(name, rank) {
  return { name, rank, header: sectionHeader(name) };
}

export const SECTION_RECOMMENDED = section(
  i18n("codemirror.expression.sections.recommended"),
  0
);
export const SECTION_PROPERTIES = section(
  i18n("codemirror.expression.sections.properties"),
  2
);
export const SECTION_METHODS = section(
  i18n("codemirror.expression.sections.methods"),
  3
);
export const SECTION_METADATA = section(
  i18n("codemirror.expression.sections.metadata"),
  4
);
export const SECTION_GLOBALS = section(
  i18n("codemirror.expression.sections.globals"),
  5
);

export function info(signature, description, example) {
  return () => {
    const div = document.createElement("div");
    div.className = "cm-expr-completion-info";

    const sig = document.createElement("div");
    sig.className = "cm-expr-completion-info__signature";
    sig.textContent = signature;
    div.appendChild(sig);

    const desc = document.createElement("div");
    desc.className = "cm-expr-completion-info__description";
    desc.textContent = description;
    div.appendChild(desc);

    if (example) {
      const ex = document.createElement("div");
      ex.className = "cm-expr-completion-info__example";
      const code = document.createElement("code");
      code.textContent = example;
      ex.appendChild(code);
      div.appendChild(ex);
    }

    return div;
  };
}

// Builds method completions, deriving each description from the type and
// label by convention: `codemirror.expression.methods.<type>.<label>`.
// Signatures and examples stay literal — they are code, not translatable prose.
function buildMethods(type, entries) {
  return entries.map((entry) => ({
    label: entry.label,
    type: entry.type,
    detail: entry.detail,
    info: info(
      entry.signature,
      i18n(`codemirror.expression.methods.${type}.${entry.label}`),
      entry.example
    ),
  }));
}

// Builds global completions, deriving each description by convention:
// `codemirror.expression.globals.<label>`.
function buildGlobals(entries) {
  return entries.map((entry) => ({
    label: entry.label,
    type: entry.type,
    detail: entry.detail,
    info: i18n(`codemirror.expression.globals.${entry.label}`),
  }));
}

export const STRING_METHODS = buildMethods("string", [
  {
    label: "length",
    type: "property",
    detail: "number",
    signature: "str.length",
  },
  {
    label: "includes",
    type: "method",
    detail: "(str) => boolean",
    signature: "str.includes(searchString, position?)",
    example: '"hello".includes("ell") → true',
  },
  {
    label: "startsWith",
    type: "method",
    detail: "(str) => boolean",
    signature: "str.startsWith(searchString, position?)",
  },
  {
    label: "endsWith",
    type: "method",
    detail: "(str) => boolean",
    signature: "str.endsWith(searchString, length?)",
  },
  {
    label: "split",
    type: "method",
    detail: "(sep) => string[]",
    signature: "str.split(separator, limit?)",
    example: '"a,b,c".split(",") → ["a","b","c"]',
  },
  {
    label: "replaceAll",
    type: "method",
    detail: "(search, replace) => string",
    signature: "str.replaceAll(search, replacement)",
  },
  {
    label: "replace",
    type: "method",
    detail: "(search, replace) => string",
    signature: "str.replace(search, replacement)",
  },
  {
    label: "trim",
    type: "method",
    detail: "() => string",
    signature: "str.trim()",
  },
  {
    label: "trimStart",
    type: "method",
    detail: "() => string",
    signature: "str.trimStart()",
  },
  {
    label: "trimEnd",
    type: "method",
    detail: "() => string",
    signature: "str.trimEnd()",
  },
  {
    label: "toLowerCase",
    type: "method",
    detail: "() => string",
    signature: "str.toLowerCase()",
  },
  {
    label: "toUpperCase",
    type: "method",
    detail: "() => string",
    signature: "str.toUpperCase()",
  },
  {
    label: "slice",
    type: "method",
    detail: "(start, end?) => string",
    signature: "str.slice(start, end?)",
    example: '"hello".slice(1, 4) → "ell"',
  },
  {
    label: "substring",
    type: "method",
    detail: "(start, end?) => string",
    signature: "str.substring(start, end?)",
  },
  {
    label: "indexOf",
    type: "method",
    detail: "(str) => number",
    signature: "str.indexOf(searchValue, fromIndex?)",
  },
  {
    label: "match",
    type: "method",
    detail: "(regex) => array",
    signature: "str.match(regexp)",
  },
  {
    label: "concat",
    type: "method",
    detail: "(...strings) => string",
    signature: "str.concat(...strings)",
  },
]);

export const NUMBER_METHODS = buildMethods("number", [
  {
    label: "toFixed",
    type: "method",
    detail: "(digits?) => string",
    signature: "num.toFixed(digits?)",
    example: '(3.14159).toFixed(2) → "3.14"',
  },
  {
    label: "toString",
    type: "method",
    detail: "(radix?) => string",
    signature: "num.toString(radix?)",
  },
  {
    label: "toPrecision",
    type: "method",
    detail: "(precision?) => string",
    signature: "num.toPrecision(precision?)",
  },
  {
    label: "toLocaleString",
    type: "method",
    detail: "() => string",
    signature: "num.toLocaleString(locales?, options?)",
  },
]);

export const BOOLEAN_METHODS = buildMethods("boolean", [
  {
    label: "toString",
    type: "method",
    detail: "() => string",
    signature: "bool.toString()",
  },
]);

export const ARRAY_METHODS = buildMethods("array", [
  {
    label: "length",
    type: "property",
    detail: "number",
    signature: "arr.length",
  },
  {
    label: "map",
    type: "method",
    detail: "(fn) => array",
    signature: "arr.map(callback)",
    example: "[1,2,3].map(x => x * 2) → [2,4,6]",
  },
  {
    label: "filter",
    type: "method",
    detail: "(fn) => array",
    signature: "arr.filter(callback)",
    example: "[1,2,3,4].filter(x => x > 2) → [3,4]",
  },
  {
    label: "find",
    type: "method",
    detail: "(fn) => item",
    signature: "arr.find(callback)",
  },
  {
    label: "includes",
    type: "method",
    detail: "(item) => boolean",
    signature: "arr.includes(value, fromIndex?)",
  },
  {
    label: "join",
    type: "method",
    detail: "(sep?) => string",
    signature: "arr.join(separator?)",
    example: '["a","b","c"].join("-") → "a-b-c"',
  },
  {
    label: "slice",
    type: "method",
    detail: "(start, end?) => array",
    signature: "arr.slice(start?, end?)",
  },
  {
    label: "sort",
    type: "method",
    detail: "(fn?) => array",
    signature: "arr.sort(compareFn?)",
  },
  {
    label: "reverse",
    type: "method",
    detail: "() => array",
    signature: "arr.reverse()",
  },
  {
    label: "reduce",
    type: "method",
    detail: "(fn, init?) => any",
    signature: "arr.reduce(callback, initialValue?)",
    example: "[1,2,3].reduce((sum, x) => sum + x, 0) → 6",
  },
  {
    label: "indexOf",
    type: "method",
    detail: "(item) => number",
    signature: "arr.indexOf(value, fromIndex?)",
  },
  {
    label: "concat",
    type: "method",
    detail: "(...arrays) => array",
    signature: "arr.concat(...values)",
  },
]);

export const DATE_METHODS = buildMethods("date", [
  {
    label: "toISOString",
    type: "method",
    detail: "() => string",
    signature: "date.toISOString()",
  },
  {
    label: "toLocaleDateString",
    type: "method",
    detail: "() => string",
    signature: "date.toLocaleDateString(locales?, options?)",
  },
  {
    label: "getTime",
    type: "method",
    detail: "() => number",
    signature: "date.getTime()",
  },
  {
    label: "getFullYear",
    type: "method",
    detail: "() => number",
    signature: "date.getFullYear()",
  },
  {
    label: "getMonth",
    type: "method",
    detail: "() => number",
    signature: "date.getMonth()",
  },
  {
    label: "getDate",
    type: "method",
    detail: "() => number",
    signature: "date.getDate()",
  },
  {
    label: "getHours",
    type: "method",
    detail: "() => number",
    signature: "date.getHours()",
  },
  {
    label: "getMinutes",
    type: "method",
    detail: "() => number",
    signature: "date.getMinutes()",
  },
  {
    label: "toLocaleString",
    type: "method",
    detail: "() => string",
    signature: "date.toLocaleString(locales?, options?)",
  },
]);

export const GLOBAL_COMPLETIONS = buildGlobals([
  { label: "Math", type: "variable", detail: "object" },
  { label: "JSON", type: "variable", detail: "object" },
  { label: "Object", type: "variable", detail: "object" },
  { label: "Array", type: "variable", detail: "object" },
  { label: "String", type: "variable", detail: "object" },
  { label: "Number", type: "variable", detail: "object" },
  { label: "Date", type: "variable", detail: "object" },
  { label: "parseInt", type: "function", detail: "(string, radix?) => number" },
  { label: "parseFloat", type: "function", detail: "(string) => number" },
  {
    label: "encodeURIComponent",
    type: "function",
    detail: "(string) => string",
  },
  {
    label: "decodeURIComponent",
    type: "function",
    detail: "(string) => string",
  },
  { label: "isNaN", type: "function", detail: "(value) => boolean" },
  { label: "isFinite", type: "function", detail: "(value) => boolean" },
]);

// Non-enumerable, so Object.keys won't find them — listed explicitly.
export const GLOBAL_STATIC_METHODS = {
  Math: [
    { label: "abs", type: "function", detail: "(x) => number" },
    { label: "ceil", type: "function", detail: "(x) => number" },
    { label: "floor", type: "function", detail: "(x) => number" },
    { label: "round", type: "function", detail: "(x) => number" },
    { label: "max", type: "function", detail: "(...values) => number" },
    { label: "min", type: "function", detail: "(...values) => number" },
    { label: "random", type: "function", detail: "() => number" },
    { label: "pow", type: "function", detail: "(base, exp) => number" },
    { label: "sqrt", type: "function", detail: "(x) => number" },
    { label: "trunc", type: "function", detail: "(x) => number" },
    { label: "PI", type: "property", detail: "number" },
  ],
  JSON: [
    { label: "parse", type: "function", detail: "(text) => any" },
    { label: "stringify", type: "function", detail: "(value) => string" },
  ],
  Object: [
    { label: "keys", type: "function", detail: "(obj) => string[]" },
    { label: "values", type: "function", detail: "(obj) => any[]" },
    { label: "entries", type: "function", detail: "(obj) => [string, any][]" },
    {
      label: "assign",
      type: "function",
      detail: "(target, ...sources) => object",
    },
    { label: "fromEntries", type: "function", detail: "(iterable) => object" },
  ],
  Array: [
    { label: "isArray", type: "function", detail: "(value) => boolean" },
    { label: "from", type: "function", detail: "(iterable) => array" },
  ],
  Number: [
    { label: "isInteger", type: "function", detail: "(value) => boolean" },
    { label: "isFinite", type: "function", detail: "(value) => boolean" },
    { label: "isNaN", type: "function", detail: "(value) => boolean" },
    { label: "parseInt", type: "function", detail: "(string) => number" },
    { label: "parseFloat", type: "function", detail: "(string) => number" },
  ],
  String: [
    { label: "fromCharCode", type: "function", detail: "(...codes) => string" },
  ],
  Date: [
    { label: "now", type: "function", detail: "() => number" },
    { label: "parse", type: "function", detail: "(string) => number" },
  ],
};

function buildMethodMap(methods) {
  return new Map(methods.map((m) => [m.label, m]));
}

const METHOD_DOCS_BY_TYPE = {
  string: buildMethodMap(STRING_METHODS),
  number: buildMethodMap(NUMBER_METHODS),
  boolean: buildMethodMap(BOOLEAN_METHODS),
  array: buildMethodMap(ARRAY_METHODS),
  date: buildMethodMap(DATE_METHODS),
};

export function lookupMethodDoc(name, parentValue) {
  if (parentValue === null || parentValue === undefined) {
    return null;
  }
  let typeName;
  if (Array.isArray(parentValue)) {
    typeName = "array";
  } else if (parentValue instanceof Date) {
    typeName = "date";
  } else {
    typeName = typeof parentValue;
  }
  return METHOD_DOCS_BY_TYPE[typeName]?.get(name) ?? null;
}

export const GLOBAL_DOCS = new Map(GLOBAL_COMPLETIONS.map((g) => [g.label, g]));
