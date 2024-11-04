import { defaultMarkdownParser, MarkdownParser } from "prosemirror-markdown";
import { getParsers } from "discourse/lib/composer/rich-editor-extensions";
import { parse as markdownItParse } from "discourse/static/markdown-it";
import loadPluginFeatures from "discourse/static/markdown-it/features";
import defaultFeatures from "discourse-markdown-it/features/index";

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

let parseOptions;
function initializeParsers() {
  if (parseOptions) {
    return;
  }

  for (const [key, value] of Object.entries(getParsers())) {
    if (typeof value === "function") {
      postParseTokens[key] = value;
    } else {
      parseTokens[key] = value;
    }
  }

  const featuresOverride = [...defaultFeatures, ...loadPluginFeatures()]
    .map(({ id }) => id)
    // avoid oneboxing when parsing
    .filter((id) => id !== "onebox");

  parseOptions = { featuresOverride };
}

export function convertFromMarkdown(schema, text) {
  initializeParsers();

  const tokens = markdownItParse(text, parseOptions);

  console.log("Converting tokens", tokens);

  const dummyTokenizer = { parse: () => tokens };
  const parser = new MarkdownParser(schema, dummyTokenizer, parseTokens);

  // workaround for custom (fn) handlers
  for (const [key, callback] of Object.entries(postParseTokens)) {
    parser.tokenHandlers[key] = callback;
  }

  return parser.parse(text);
}
