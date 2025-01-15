import { defaultMarkdownParser, MarkdownParser } from "prosemirror-markdown";
import { parse } from "../lib/markdown-it";

// TODO(renato): We need a workaround for this parsing issue:
//   https://github.com/ProseMirror/prosemirror-markdown/issues/82
//   a solution may be a markStack in the state ignoring nested marks

export default class Parser {
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

    for (const [key, value] of Object.entries(extractParsers(extensions))) {
      // Not a ParseSpec
      if (typeof value === "function") {
        this.postParseTokens[key] = value;
      } else {
        this.parseTokens[key] = value;
      }
    }
  }

  convert(schema, text) {
    const tokens = parse(text);

    console.log("Converting tokens", tokens);

    const dummyTokenizer = { parse: () => tokens };
    const parser = new MarkdownParser(schema, dummyTokenizer, this.parseTokens);

    // Adding function parse handlers directly
    for (const [key, callback] of Object.entries(this.postParseTokens)) {
      parser.tokenHandlers[key] = callback;
    }

    return parser.parse(text);
  }
}

/**
 * Node names to be processed allowing multiple occurrences, with its respective `noCloseToken` boolean definition
 * @type {Record<string, boolean>}
 */
const MULTIPLE_ALLOWED = { span: false, wrap_bbcode: true, bbcode: false };

function extractParsers(extensions) {
  const parsers = extensions.reduce((acc, { parse: parseObj }) => {
    if (parseObj) {
      Object.entries(parseObj).forEach(([token, parseSpec]) => {
        if (MULTIPLE_ALLOWED[token] !== undefined) {
          acc[token] ??= [];
          acc[token].push(parseSpec);
          return;
        }
        acc[token] = parseSpec;
      });
    }

    return acc;
  }, {});

  for (const [tokenName, noCloseToken] of Object.entries(MULTIPLE_ALLOWED)) {
    const parseList = parsers[tokenName];
    delete parsers[tokenName];
    Object.assign(
      parsers,
      generateMultipleParser(tokenName, parseList, noCloseToken)
    );
  }

  return parsers;
}

function generateMultipleParser(tokenName, list, noCloseToken) {
  if (noCloseToken) {
    return {
      [tokenName](state, token, tokens, i) {
        if (!list) {
          return;
        }

        for (let parser of list) {
          // Stop once a parse function returns true
          if (parser(state, token, tokens, i)) {
            return;
          }
        }
        throw new Error(
          `No parser to process ${tokenName} token. Tag: ${
            token.tag
          }, attrs: ${JSON.stringify(token.attrs)}`
        );
      },
    };
  } else {
    return {
      [`${tokenName}_open`](state, token, tokens, i) {
        if (!list) {
          return;
        }

        state[`skip${tokenName}CloseStack`] ??= [];

        let handled = false;
        for (let parser of list) {
          if (parser(state, token, tokens, i)) {
            handled = true;
            break;
          }
        }

        state[`skip${tokenName}CloseStack`].push(!handled);
      },
      [`${tokenName}_close`](state) {
        if (!list || !state[`skip${tokenName}CloseStack`]) {
          return;
        }

        const skipCurrentLevel = state[`skip${tokenName}CloseStack`].pop();
        if (skipCurrentLevel) {
          return;
        }

        state.closeNode();
      },
    };
  }
}
