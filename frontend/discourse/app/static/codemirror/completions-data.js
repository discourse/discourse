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

export const SECTION_RECOMMENDED = section("Recommended", 0);
export const SECTION_PROPERTIES = section("Properties", 2);
export const SECTION_METHODS = section("Methods", 3);
export const SECTION_METADATA = section("Metadata", 4);
export const SECTION_GLOBALS = section("Globals", 5);

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

export const STRING_METHODS = [
  {
    label: "length",
    type: "property",
    detail: "number",
    info: info("str.length", "The number of characters in the string."),
  },
  {
    label: "includes",
    type: "method",
    detail: "(str) => boolean",
    info: info(
      "str.includes(searchString, position?)",
      "Returns true if the string contains the substring.",
      '"hello".includes("ell") → true'
    ),
  },
  {
    label: "startsWith",
    type: "method",
    detail: "(str) => boolean",
    info: info(
      "str.startsWith(searchString, position?)",
      "Returns true if the string starts with the given characters."
    ),
  },
  {
    label: "endsWith",
    type: "method",
    detail: "(str) => boolean",
    info: info(
      "str.endsWith(searchString, length?)",
      "Returns true if the string ends with the given characters."
    ),
  },
  {
    label: "split",
    type: "method",
    detail: "(sep) => string[]",
    info: info(
      "str.split(separator, limit?)",
      "Splits the string into an array of substrings.",
      '"a,b,c".split(",") → ["a","b","c"]'
    ),
  },
  {
    label: "replaceAll",
    type: "method",
    detail: "(search, replace) => string",
    info: info(
      "str.replaceAll(search, replacement)",
      "Replaces all occurrences of a search string."
    ),
  },
  {
    label: "replace",
    type: "method",
    detail: "(search, replace) => string",
    info: info(
      "str.replace(search, replacement)",
      "Replaces the first occurrence of a search string."
    ),
  },
  {
    label: "trim",
    type: "method",
    detail: "() => string",
    info: info(
      "str.trim()",
      "Removes whitespace from both ends of the string."
    ),
  },
  {
    label: "trimStart",
    type: "method",
    detail: "() => string",
    info: info(
      "str.trimStart()",
      "Removes whitespace from the beginning of the string."
    ),
  },
  {
    label: "trimEnd",
    type: "method",
    detail: "() => string",
    info: info(
      "str.trimEnd()",
      "Removes whitespace from the end of the string."
    ),
  },
  {
    label: "toLowerCase",
    type: "method",
    detail: "() => string",
    info: info("str.toLowerCase()", "Converts the string to lowercase."),
  },
  {
    label: "toUpperCase",
    type: "method",
    detail: "() => string",
    info: info("str.toUpperCase()", "Converts the string to uppercase."),
  },
  {
    label: "slice",
    type: "method",
    detail: "(start, end?) => string",
    info: info(
      "str.slice(start, end?)",
      "Extracts a section of the string.",
      '"hello".slice(1, 4) → "ell"'
    ),
  },
  {
    label: "substring",
    type: "method",
    detail: "(start, end?) => string",
    info: info(
      "str.substring(start, end?)",
      "Returns the part of the string between two indices."
    ),
  },
  {
    label: "indexOf",
    type: "method",
    detail: "(str) => number",
    info: info(
      "str.indexOf(searchValue, fromIndex?)",
      "Returns the index of the first occurrence, or -1 if not found."
    ),
  },
  {
    label: "match",
    type: "method",
    detail: "(regex) => array",
    info: info(
      "str.match(regexp)",
      "Matches the string against a regular expression."
    ),
  },
  {
    label: "concat",
    type: "method",
    detail: "(...strings) => string",
    info: info("str.concat(...strings)", "Concatenates one or more strings."),
  },
];

export const NUMBER_METHODS = [
  {
    label: "toFixed",
    type: "method",
    detail: "(digits?) => string",
    info: info(
      "num.toFixed(digits?)",
      "Formats the number with a fixed number of decimal places.",
      '(3.14159).toFixed(2) → "3.14"'
    ),
  },
  {
    label: "toString",
    type: "method",
    detail: "(radix?) => string",
    info: info(
      "num.toString(radix?)",
      "Returns a string representation of the number."
    ),
  },
  {
    label: "toPrecision",
    type: "method",
    detail: "(precision?) => string",
    info: info(
      "num.toPrecision(precision?)",
      "Formats the number to a specified precision."
    ),
  },
  {
    label: "toLocaleString",
    type: "method",
    detail: "() => string",
    info: info(
      "num.toLocaleString(locales?, options?)",
      "Returns a locale-sensitive string representation."
    ),
  },
];

export const BOOLEAN_METHODS = [
  {
    label: "toString",
    type: "method",
    detail: "() => string",
    info: info(
      "bool.toString()",
      "Converts true to 'true' and false to 'false'."
    ),
  },
];

export const ARRAY_METHODS = [
  {
    label: "length",
    type: "property",
    detail: "number",
    info: info("arr.length", "The number of elements in the array."),
  },
  {
    label: "map",
    type: "method",
    detail: "(fn) => array",
    info: info(
      "arr.map(callback)",
      "Creates a new array with the results of calling a function on every element.",
      "[1,2,3].map(x => x * 2) → [2,4,6]"
    ),
  },
  {
    label: "filter",
    type: "method",
    detail: "(fn) => array",
    info: info(
      "arr.filter(callback)",
      "Creates a new array with elements that pass the test.",
      "[1,2,3,4].filter(x => x > 2) → [3,4]"
    ),
  },
  {
    label: "find",
    type: "method",
    detail: "(fn) => item",
    info: info(
      "arr.find(callback)",
      "Returns the first element that satisfies the testing function."
    ),
  },
  {
    label: "includes",
    type: "method",
    detail: "(item) => boolean",
    info: info(
      "arr.includes(value, fromIndex?)",
      "Returns true if the array contains the specified value."
    ),
  },
  {
    label: "join",
    type: "method",
    detail: "(sep?) => string",
    info: info(
      "arr.join(separator?)",
      "Joins all elements into a string.",
      '["a","b","c"].join("-") → "a-b-c"'
    ),
  },
  {
    label: "slice",
    type: "method",
    detail: "(start, end?) => array",
    info: info(
      "arr.slice(start?, end?)",
      "Returns a shallow copy of a portion of the array."
    ),
  },
  {
    label: "sort",
    type: "method",
    detail: "(fn?) => array",
    info: info(
      "arr.sort(compareFn?)",
      "Sorts the elements of the array in place."
    ),
  },
  {
    label: "reverse",
    type: "method",
    detail: "() => array",
    info: info("arr.reverse()", "Reverses the order of elements."),
  },
  {
    label: "reduce",
    type: "method",
    detail: "(fn, init?) => any",
    info: info(
      "arr.reduce(callback, initialValue?)",
      "Reduces the array to a single value.",
      "[1,2,3].reduce((sum, x) => sum + x, 0) → 6"
    ),
  },
  {
    label: "indexOf",
    type: "method",
    detail: "(item) => number",
    info: info(
      "arr.indexOf(value, fromIndex?)",
      "Returns the first index of the value, or -1 if not found."
    ),
  },
  {
    label: "concat",
    type: "method",
    detail: "(...arrays) => array",
    info: info(
      "arr.concat(...values)",
      "Merges arrays and/or values into a new array."
    ),
  },
];

export const DATE_METHODS = [
  {
    label: "toISOString",
    type: "method",
    detail: "() => string",
    info: info("date.toISOString()", "Returns the date as an ISO 8601 string."),
  },
  {
    label: "toLocaleDateString",
    type: "method",
    detail: "() => string",
    info: info(
      "date.toLocaleDateString(locales?, options?)",
      "Returns a locale-sensitive date string."
    ),
  },
  {
    label: "getTime",
    type: "method",
    detail: "() => number",
    info: info("date.getTime()", "Returns milliseconds since Unix epoch."),
  },
  {
    label: "getFullYear",
    type: "method",
    detail: "() => number",
    info: info("date.getFullYear()", "Returns the four-digit year."),
  },
  {
    label: "getMonth",
    type: "method",
    detail: "() => number",
    info: info("date.getMonth()", "Returns the month (0-11)."),
  },
  {
    label: "getDate",
    type: "method",
    detail: "() => number",
    info: info("date.getDate()", "Returns the day of the month (1-31)."),
  },
  {
    label: "getHours",
    type: "method",
    detail: "() => number",
    info: info("date.getHours()", "Returns the hour (0-23)."),
  },
  {
    label: "getMinutes",
    type: "method",
    detail: "() => number",
    info: info("date.getMinutes()", "Returns the minutes (0-59)."),
  },
  {
    label: "toLocaleString",
    type: "method",
    detail: "() => string",
    info: info(
      "date.toLocaleString(locales?, options?)",
      "Returns a locale-sensitive date and time string."
    ),
  },
];

export const GLOBAL_COMPLETIONS = [
  {
    label: "Math",
    type: "variable",
    detail: "object",
    info: "Mathematical constants and functions (Math.round, Math.random, etc.)",
  },
  {
    label: "JSON",
    type: "variable",
    detail: "object",
    info: "JSON parsing and serialization (JSON.parse, JSON.stringify).",
  },
  {
    label: "Object",
    type: "variable",
    detail: "object",
    info: "Object utilities (Object.keys, Object.values, Object.entries).",
  },
  {
    label: "Array",
    type: "variable",
    detail: "object",
    info: "Array utilities (Array.isArray, Array.from).",
  },
  {
    label: "String",
    type: "variable",
    detail: "object",
    info: "String constructor and utilities.",
  },
  {
    label: "Number",
    type: "variable",
    detail: "object",
    info: "Number utilities (Number.isInteger, Number.parseFloat).",
  },
  {
    label: "Date",
    type: "variable",
    detail: "object",
    info: "Date constructor. Use new Date() to create dates.",
  },
  {
    label: "parseInt",
    type: "function",
    detail: "(string, radix?) => number",
    info: "Parses a string and returns an integer.",
  },
  {
    label: "parseFloat",
    type: "function",
    detail: "(string) => number",
    info: "Parses a string and returns a floating-point number.",
  },
  {
    label: "encodeURIComponent",
    type: "function",
    detail: "(string) => string",
    info: "Encodes a URI component by replacing special characters.",
  },
  {
    label: "decodeURIComponent",
    type: "function",
    detail: "(string) => string",
    info: "Decodes an encoded URI component.",
  },
  {
    label: "isNaN",
    type: "function",
    detail: "(value) => boolean",
    info: "Returns true if the value is NaN.",
  },
  {
    label: "isFinite",
    type: "function",
    detail: "(value) => boolean",
    info: "Returns true if the value is a finite number.",
  },
];

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
