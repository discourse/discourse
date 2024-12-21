import { defaultMarkdownParser, MarkdownParser } from "prosemirror-markdown";
import { getParsers } from "discourse/lib/composer/rich-editor-extensions";
import { parse } from "./markdown-it";

// TODO(renato): We need a workaround for this parsing issue:
//   https://github.com/ProseMirror/prosemirror-markdown/issues/82
//   a solution may be a markStack in the state ignoring nested marks

const parseTokens = {
  ...defaultMarkdownParser.tokens,
  bbcode_b: { mark: "strong" },
  bbcode_i: { mark: "em" },
};

// Overriding Prosemirror default parse definitions with custom handlers
const postParseTokens = {
  softbreak: (state) => state.addNode(state.schema.nodes.hard_break),
};

let initialized;
function ensureCustomParsers() {
  if (initialized) {
    return;
  }

  for (const [key, value] of Object.entries(getParsers())) {
    if (typeof value === "function") {
      postParseTokens[key] = value;
    } else {
      parseTokens[key] = value;
    }
  }

  initialized = true;
}

export function convertFromMarkdown(schema, text) {
  ensureCustomParsers();

  const tokens = parse(text);

  console.log("Converting tokens", tokens);

  const dummyTokenizer = { parse: () => tokens };
  const parser = new MarkdownParser(schema, dummyTokenizer, parseTokens);

  for (const [key, callback] of Object.entries(postParseTokens)) {
    parser.tokenHandlers[key] = callback;
  }

  return parser.parse(text);
}
