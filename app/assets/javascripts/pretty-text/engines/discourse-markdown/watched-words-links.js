function isLinkOpen(str) {
  return /^<a[>\s]/i.test(str);
}

function isLinkClose(str) {
  return /^<\/a\s*>/i.test(str);
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    const watchedWordsLinks = md.options.discourse.watchedWordsLinks;
    const regexp = new RegExp(Object.keys(watchedWordsLinks).join("|"), "gi");

    md.core.ruler.push("watched-words-links", (state) => {
      let token, currentToken, nodes, text, pos, level;

      for (let j = 0, l = state.tokens.length; j < l; j++) {
        if (state.tokens[j].type !== "inline") {
          continue;
        }

        let tokens = state.tokens[j].children;

        let htmlLinkLevel = 0;

        // We scan from the end, to keep position when new tags added.
        // Use reversed logic in links start/end match
        for (let i = tokens.length - 1; i >= 0; i--) {
          currentToken = tokens[i];

          // Skip content of markdown links
          if (currentToken.type === "link_close") {
            i--;
            while (
              tokens[i].level !== currentToken.level &&
              tokens[i].type !== "link_open"
            ) {
              i--;
            }
            continue;
          }

          // Skip content of html tag links
          if (currentToken.type === "html_inline") {
            if (isLinkOpen(currentToken.content) && htmlLinkLevel > 0) {
              htmlLinkLevel--;
            }

            if (isLinkClose(currentToken.content)) {
              htmlLinkLevel++;
            }
          }

          if (htmlLinkLevel > 0) {
            continue;
          }

          if (currentToken.type === "text") {
            text = currentToken.content;

            // Now split string to nodes
            nodes = [];
            level = currentToken.level;
            let lastPos = 0;

            let match;
            while ((match = regexp.exec(text)) !== null) {
              let url = watchedWordsLinks[match[0]];
              let fullUrl = state.md.normalizeLink(url);
              if (!state.md.validateLink(fullUrl)) {
                continue;
              }

              pos = match.index;

              if (pos > lastPos) {
                token = new state.Token("text", "", 0);
                token.content = text.slice(lastPos, pos);
                token.level = level;
                nodes.push(token);
              }

              token = new state.Token("link_open", "a", 1);
              token.attrs = [["href", fullUrl]];
              token.level = level++;
              token.markup = "linkify";
              token.info = "auto";
              nodes.push(token);

              token = new state.Token("text", "", 0);
              token.content = match[0];
              token.level = level;
              nodes.push(token);

              token = new state.Token("link_close", "a", -1);
              token.level = --level;
              token.markup = "linkify";
              token.info = "auto";
              nodes.push(token);

              lastPos = match.index + match[0].length;
            }

            if (lastPos < text.length) {
              token = new state.Token("text", "", 0);
              token.content = text.slice(lastPos);
              token.level = level;
              nodes.push(token);
            }

            // replace current node
            state.tokens[j].children = tokens = md.utils.arrayReplaceAt(
              tokens,
              i,
              nodes
            );
          }
        }
      }
    });
  });
}
