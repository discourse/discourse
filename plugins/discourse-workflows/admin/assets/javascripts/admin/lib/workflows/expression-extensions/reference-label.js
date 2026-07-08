import { i18n } from "discourse-i18n";

// Parses a "simple reference" into source + path. Anything more involved
// (operators, arithmetic, multiple refs, method calls) returns null.

// Matches a leading $('Node Name') / $("Node Name") node reference.
const NODE_REF_RE = /^\$\((?:"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)')\)/;

// An item selector after a node/$input ref: .first(), .item, .itemMatching('x')…
const SELECTOR_RE =
  /^(?:\.(?:first|last|all|itemMatching|pairedItem)\([^()]*\)|\.item)/;

// A plain property path: dotted identifiers and numeric/string subscripts.
const PATH_TOKEN =
  "[A-Za-z_$][\\w$]*|\\[\\d+\\]|\\['(?:[^'\\\\]|\\\\.)*'\\]|\\[\"(?:[^\"\\\\]|\\\\.)*\"\\]";
const PLAIN_PATH_RE = new RegExp(
  `^(?:${PATH_TOKEN})(?:\\.[A-Za-z_$][\\w$]*|\\[\\d+\\]|\\['(?:[^'\\\\]|\\\\.)*'\\]|\\["(?:[^"\\\\]|\\\\.)*"\\])*$`
);

const ROOT_SOURCES = {
  $json: "input",
  $trigger: "trigger",
  $itemIndex: "item_index",
  $vars: "variable",
  $current_user: "current_user",
  $site_settings: "site_setting",
  $execution: "execution",
};

const SOURCE_ICONS = {
  node: "diagram-project",
  input: "right-to-bracket",
  trigger: "play",
  item_index: "hashtag",
  variable: "dollar-sign",
  current_user: "user",
  site_setting: "gear",
  execution: "bolt",
};

function parseNodeReferenceName(match) {
  const doubleQuoted = match[1] !== undefined;
  const raw = doubleQuoted ? match[1] : match[2];

  if (doubleQuoted) {
    try {
      return JSON.parse(`"${raw}"`);
    } catch {
      return raw;
    }
  }

  return raw.replace(/\\([\\'])/g, "$1");
}

function stripLeadingDot(text) {
  return text.startsWith(".") ? text.slice(1) : text;
}

function isPlainPath(path) {
  return path === "" || PLAIN_PATH_RE.test(path);
}

function firstSeparator(text) {
  for (let i = 0; i < text.length; i++) {
    if (text[i] === "." || text[i] === "[") {
      return i;
    }
  }
  return -1;
}

// Pulls the path out of a `[selector].json[.path]` tail, or null if not plain.
function parseJsonTail(rest) {
  const selector = SELECTOR_RE.exec(rest);
  if (selector) {
    rest = rest.slice(selector[0].length);
  }

  if (!rest.startsWith(".json")) {
    return null;
  }
  rest = rest.slice(".json".length);

  const path = stripLeadingDot(rest);
  return isPlainPath(path) ? path : null;
}

export function parseReference(expression) {
  const text = (expression || "").trim();
  if (!text) {
    return null;
  }

  const nodeRef = NODE_REF_RE.exec(text);
  if (nodeRef) {
    const name = parseNodeReferenceName(nodeRef);
    const path = parseJsonTail(text.slice(nodeRef[0].length));
    if (!name || path === null) {
      return null;
    }
    return { source: { type: "node", name }, path };
  }

  const separator = firstSeparator(text);
  const root = separator === -1 ? text : text.slice(0, separator);
  const remainder = separator === -1 ? "" : text.slice(separator);

  if (root === "$input") {
    const path = parseJsonTail(remainder);
    if (path === null) {
      return null;
    }
    return { source: { type: "input" }, path };
  }

  const type = ROOT_SOURCES[root];
  if (!type) {
    return null;
  }

  const path = stripLeadingDot(remainder);
  if (!isPlainPath(path)) {
    return null;
  }
  return { source: { type }, path };
}

export function referenceLabel(parsed) {
  if (!parsed) {
    return null;
  }

  const { source, path } = parsed;
  const badge =
    source.type === "node"
      ? source.name
      : i18n(`discourse_workflows.reference_pill.source.${source.type}`);

  return {
    sourceType: source.type,
    icon: SOURCE_ICONS[source.type],
    badge,
    path,
  };
}
