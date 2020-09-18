// since the markdown.it interface is a bit on the verbose side
// we can keep some general patterns here

export default null;

// creates a rule suitable for inline parsing and replacement
//
// example:
// const rule = inlineRegexRule(md, {
//   start: '#',
//   matcher: /^#([\w-:]{1,101})/i,
//   emitter: emitter
// });

// based off https://github.com/markdown-it/markdown-it-emoji/blob/master/dist/markdown-it-emoji.js
//
export function textReplace(state, callback, skipAllLinks) {
  var i,
    j,
    l,
    tokens,
    token,
    blockTokens = state.tokens,
    linkLevel = 0;

  for (j = 0, l = blockTokens.length; j < l; j++) {
    if (blockTokens[j].type !== "inline") {
      continue;
    }
    tokens = blockTokens[j].children;

    // We scan from the end, to keep position when new tags added.
    // Use reversed logic in links start/end match
    for (i = tokens.length - 1; i >= 0; i--) {
      token = tokens[i];

      if (skipAllLinks) {
        if (token.type === "link_open" || token.type === "link_close") {
          linkLevel -= token.nesting;
        } else if (token.type === "html_inline") {
          const openLink = token.content.substr(0, 2).toLowerCase();

          if (openLink === "<a") {
            if (token.content.match(/^<a(\s.*)?>/i)) {
              linkLevel++;
            }
          } else if (token.content.substr(0, 4).toLowerCase() === "</a>") {
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
