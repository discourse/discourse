import { defaultMarkdownParser, MarkdownParser } from "prosemirror-markdown";
import { getParsers } from "discourse/lib/composer/rich-editor-extensions";
import { parseAsync } from "discourse/lib/text";

// TODO(renato): We need a workaround for this parsing issue:
//   https://github.com/ProseMirror/prosemirror-markdown/issues/82
//   a solution may be a markStack in the state ignoring nested marks

const [parseFunctions, parseDefinitions] = Object.entries(getParsers()).reduce(
  ([funcs, nonFuncs], [key, value]) => {
    if (typeof value === "function") {
      funcs[key] = value;
    } else {
      nonFuncs[key] = value;
    }
    return [funcs, nonFuncs];
  },
  [{}, {}]
);

const parseTokens = {
  ...defaultMarkdownParser.tokens,

  // Custom
  bbcode_b: { mark: "strong" },
  bbcode_i: { mark: "em" },
  // TODO(renato): html_block should be like a passthrough code block
  html_block: { block: "paragraph", noCloseToken: true },
  ...parseDefinitions,
};

// Overriding Prosemirror default parse definitions
const postParseTokens = {
  softbreak: (state) => state.addText("\n"),
  ...parseFunctions,
};

export async function convertFromMarkdown(schema, text) {
  const tokens = await parseAsync(text);

  console.log("Converting tokens", tokens);

  const dummyTokenizer = { parse: () => tokens };
  const parser = new MarkdownParser(schema, dummyTokenizer, parseTokens);

  // workaround for custom (fn) handlers
  for (const [key, callback] of Object.entries(postParseTokens)) {
    parser.tokenHandlers[key] = callback;
  }

  return parser.parse(text);
}
