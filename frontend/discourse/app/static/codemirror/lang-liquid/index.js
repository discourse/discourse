import { StreamLanguage } from "@codemirror/language";
import { tags as t } from "@lezer/highlight";

const TAG_KEYWORDS = new Set([
  "assign",
  "break",
  "capture",
  "case",
  "comment",
  "continue",
  "cycle",
  "decrement",
  "echo",
  "else",
  "elsif",
  "endcapture",
  "endcase",
  "endcomment",
  "endfor",
  "endif",
  "endraw",
  "endtablerow",
  "endunless",
  "for",
  "if",
  "increment",
  "liquid",
  "raw",
  "render",
  "tablerow",
  "unless",
  "when",
]);

const OPERATOR_KEYWORDS = new Set([
  "and",
  "as",
  "by",
  "contains",
  "in",
  "or",
  "with",
]);

const BOOLEANS = new Set(["false", "true"]);
const NULLISH = new Set(["blank", "empty", "nil", "null"]);

const IDENTIFIER_RE = /[\w-]/;

function tokenizeText(stream, state) {
  if (stream.match("{{")) {
    state.context = "output";
    state.expectTagName = false;
    state.afterDot = false;
    state.afterPipe = false;
    stream.eat("-");
    return "brace";
  }

  if (stream.match("{%")) {
    state.context = "tag";
    state.expectTagName = true;
    state.afterDot = false;
    state.afterPipe = false;
    stream.eat("-");
    return "brace";
  }

  // Run to the next delimiter so a stretch of plain text is a single token.
  while (!stream.eol()) {
    stream.next();
    if (stream.match("{{", false) || stream.match("{%", false)) {
      break;
    }
  }
  return "content";
}

function tokenizeInside(stream, state) {
  const close = state.context === "output" ? /^-?\}\}/ : /^-?%\}/;
  if (stream.match(close)) {
    state.context = "text";
    return "brace";
  }

  if (stream.eatSpace()) {
    return null;
  }

  const char = stream.peek();

  if (char === '"' || char === "'") {
    stream.next();
    while (!stream.eol()) {
      if (stream.next() === char) {
        break;
      }
    }
    state.afterDot = false;
    state.afterPipe = false;
    return "string";
  }

  if (/\d/.test(char)) {
    stream.eatWhile(/[\d.]/);
    state.afterDot = false;
    state.afterPipe = false;
    return "number";
  }

  if (stream.eat(".")) {
    state.afterDot = true;
    return "punctuation";
  }

  if (stream.eat("|")) {
    state.afterPipe = true;
    state.afterDot = false;
    return "operator";
  }

  if (stream.match(/^(==|!=|<=|>=|<|>|=)/)) {
    state.afterDot = false;
    state.afterPipe = false;
    return "operator";
  }

  if (stream.match(/^[[\],:()]/)) {
    state.afterDot = false;
    return "punctuation";
  }

  if (IDENTIFIER_RE.test(char)) {
    const start = stream.pos;
    stream.eatWhile(IDENTIFIER_RE);
    const word = stream.string.slice(start, stream.pos);
    const { afterDot, afterPipe, expectTagName } = state;
    state.afterDot = false;
    state.afterPipe = false;
    state.expectTagName = false;

    if (expectTagName) {
      return TAG_KEYWORDS.has(word) ? "keyword" : "variableName";
    }
    if (afterPipe) {
      return "filter";
    }
    if (afterDot) {
      return "propertyName";
    }
    if (OPERATOR_KEYWORDS.has(word)) {
      return "keyword";
    }
    if (BOOLEANS.has(word)) {
      return "bool";
    }
    if (NULLISH.has(word)) {
      return "null";
    }
    return "variableName";
  }

  stream.next();
  return null;
}

const liquidStreamParser = {
  name: "liquid",

  startState() {
    return {
      context: "text",
      expectTagName: false,
      afterDot: false,
      afterPipe: false,
    };
  },

  token(stream, state) {
    if (state.context === "text") {
      return tokenizeText(stream, state);
    }
    return tokenizeInside(stream, state);
  },

  languageData: {
    commentTokens: {
      block: { open: "{% comment %}", close: "{% endcomment %}" },
    },
    closeBrackets: { brackets: ["(", "[", "'", '"'] },
  },

  tokenTable: {
    content: t.content,
    brace: t.brace,
    keyword: t.keyword,
    string: t.string,
    number: t.number,
    bool: t.bool,
    null: t.null,
    variableName: t.variableName,
    propertyName: t.propertyName,
    filter: t.function(t.variableName),
    operator: t.operator,
    punctuation: t.punctuation,
  },
};

export function liquidLanguage() {
  return StreamLanguage.define(liquidStreamParser);
}
