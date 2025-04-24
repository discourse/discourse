import { defaultMarkdownParser, MarkdownParser } from "prosemirror-markdown";
import { parse } from "../lib/markdown-it";

// TODO(renato): We need a workaround for this parsing issue:
//   https://github.com/ProseMirror/prosemirror-markdown/issues/82
//   a solution may be a markStack in the state ignoring nested marks

export default class Parser {
  #multipleParseSpecs = {};

  constructor(extensions, params, includeDefault = true) {
    this.params = params;
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
    Object.assign(parser.tokenHandlers, this.postParseTokens);

    return parser.parse(text);
  }

  #extractParsers(extensions) {
    const parsers = {};
    for (let { parse: parseObj } of extensions) {
      if (!parseObj) {
        continue;
      }

      if (parseObj instanceof Function) {
        parseObj = parseObj(this.params);
      }

      for (const [token, parseSpec] of Object.entries(parseObj)) {
        if (parsers[token] !== undefined) {
          if (this.#multipleParseSpecs[token] === undefined) {
            // switch to use multipleParseSpecs
            this.#multipleParseSpecs[token] = [parsers[token]];
            parsers[token] = this.#multipleParser(token);
          }
          this.#multipleParseSpecs[token].push(parseSpec);
          continue;
        }
        parsers[token] = parseSpec;
      }
    }
    return parsers;
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
