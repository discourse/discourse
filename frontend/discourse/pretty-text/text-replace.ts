// since the markdown.it interface is a bit on the verbose side
// we can keep some general patterns here

// creates a rule suitable for inline parsing and replacement
//
// example:
// const rule = inlineRegexRule(md, {
//   start: '#',
//   matcher: /^#([\w-:]{1,101})/i,
//   emitter: emitter
// });

/** The fields of a markdown-it token that `textReplace` reads. */
export interface TextReplaceToken {
  type: string;
  content: string;
  info: string;
  nesting: number;
  children: TextReplaceToken[] | null;
}

/** The parts of a markdown-it core rule's state that `textReplace` uses. */
export interface TextReplaceState {
  tokens: TextReplaceToken[];
  md: {
    utils: {
      arrayReplaceAt(
        src: TextReplaceToken[],
        pos: number,
        newElements: TextReplaceToken[]
      ): TextReplaceToken[];
    };
  };
}

// based off https://github.com/markdown-it/markdown-it-emoji/blob/master/dist/markdown-it-emoji.js
//
/**
 * Replaces the text tokens of every inline block with the tokens a callback
 * returns.
 *
 * @param state - The state of a markdown-it core rule.
 * @param callback - Called with the content of each text token that isn't
 *   skipped. It returns the tokens that replace it, or a falsy value to keep it.
 * @param skipAllLinks - Whether to skip the text inside every link. When
 *   false, only the text inside autolinks is skipped.
 */
export function textReplace<State extends TextReplaceState>(
  state: State,
  callback: (
    content: string,
    state: State
  ) => TextReplaceToken[] | null | undefined | false,
  skipAllLinks?: boolean
) {
  const blockTokens = state.tokens;
  let i: number,
    j: number,
    l: number,
    tokens: TextReplaceToken[],
    token: TextReplaceToken,
    linkLevel = 0;

  for (j = 0, l = blockTokens.length; j < l; j++) {
    if (blockTokens[j].type !== "inline") {
      continue;
    }
    // Inline tokens always have children.
    tokens = blockTokens[j].children!;

    // We scan from the end, to keep position when new tags added.
    // Use reversed logic in links start/end match
    for (i = tokens.length - 1; i >= 0; i--) {
      token = tokens[i];

      if (skipAllLinks) {
        if (token.type === "link_open" || token.type === "link_close") {
          linkLevel -= token.nesting;
        } else if (token.type === "html_inline") {
          const openLink = token.content.slice(0, 2).toLowerCase();

          if (openLink === "<a") {
            if (token.content.match(/^<a(\s.*)?>/i)) {
              linkLevel++;
            }
          } else if (token.content.slice(0, 4).toLowerCase() === "</a>") {
            linkLevel--;
          }
        }
      } else {
        if (token.type === "link_open" || token.type === "link_close") {
          if (token.info === "auto") {
            linkLevel -= token.nesting;
          }
        }
      }

      if (token.type === "text" && linkLevel === 0) {
        let split;
        if ((split = callback(token.content, state))) {
          // replace current node
          blockTokens[j].children = tokens = state.md.utils.arrayReplaceAt(
            tokens,
            i,
            split
          );
        }
      }
    }
  }
}
