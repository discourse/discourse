import { defaultMarkdownParser, MarkdownParser } from "prosemirror-markdown";
import { parse } from "../lib/markdown-it";

// TODO(renato): We need a workaround for this parsing issue:
//   https://github.com/ProseMirror/prosemirror-markdown/issues/82
//   a solution may be a markStack in the state ignoring nested marks

export default class Parser {
  #multipleParseSpecs = {};

  constructor(extensions, includeDefault = true) {
    this.parseTokens = includeDefault
      ? {
          ...defaultMarkdownParser.tokens,
          bbcode_b: { mark: "strong" },
          bbcode_i: { mark: "em" },
        }
      : {};

    this.postParseTokens = includeDefault
      ? { softbreak: (state) => state.addNode(state.schema.nodes.hard_break) }
      : {};

    for (const [key, value] of Object.entries(
      this.#extractParsers(extensions)
    )) {
      // Not a ParseSpec
      if (typeof value === "function") {
        this.postParseTokens[key] = value;
      } else {
        this.parseTokens[key] = value;
      }
    }
  }

  convert(schema, text) {
    const parser = new MarkdownParser(schema, { parse }, this.parseTokens);

    // Adding function parse handlers directly
    for (const [key, callback] of Object.entries(this.postParseTokens)) {
      parser.tokenHandlers[key] = callback;
    }

    return parser.parse(text);
  }

  #extractParsers(extensions) {
    return extensions.reduce((acc, { parse: parseObj }) => {
      if (parseObj) {
        Object.entries(parseObj).forEach(([token, parseSpec]) => {
          if (acc[token] !== undefined) {
            if (this.#multipleParseSpecs[token] === undefined) {
              // switch to use multipleParseSpecs
              this.#multipleParseSpecs[token] = [acc[token]];
              acc[token] = this.#multipleParser(token);
            }

            this.#multipleParseSpecs[token].push(parseSpec);
            return;
          }
          acc[token] = parseSpec;
        });
      }

      return acc;
    }, {});
  }

  #multipleParser(tokenName) {
    return (state, token, tokens, i) => {
      const parseSpecs = this.#multipleParseSpecs[tokenName];

      for (const parseSpec of parseSpecs) {
        if (parseSpec(state, token, tokens, i)) {
          return;
        }
      }

      throw new Error(
        `No parser processed ${tokenName} token for tag: ${
          token.tag
        }, attrs: ${JSON.stringify(token.attrs)}`
      );
    };
  }
}
