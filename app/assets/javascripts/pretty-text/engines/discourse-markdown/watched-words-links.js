function isLinkOpen(str) {
  return /^<a[>\s]/i.test(str);
}

function isLinkClose(str) {
  return /^<\/a\s*>/i.test(str);
}

function match(text, matchers) {
  const matches = [];

  matchers.forEach((matcher) => {
    let m;
    while ((m = matcher.regexp.exec(text)) !== null) {
      matches.push({
        url: matcher.url,
        index: m.index,
        text: m[0],
      });
    }
  });

  return matches.sort((a, b) => a.index - b.index);
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    const watchedWordsLinks = md.options.discourse.watchedWordsLinks;
    if (!watchedWordsLinks) {
      return;
    }

    const matchers = Object.keys(watchedWordsLinks).map((word) => ({
      regexp: new RegExp(word, "gi"),
      url: watchedWordsLinks[word],
    }));

    const cache = {};

    md.core.ruler.push("watched-words-links", (state) => {
      for (let j = 0, l = state.tokens.length; j < l; j++) {
        if (state.tokens[j].type !== "inline") {
          continue;
        }

        let tokens = state.tokens[j].children;

        let htmlLinkLevel = 0;

        // We scan from the end, to keep position when new tags added.
        // Use reversed logic in links start/end match
        for (let i = tokens.length - 1; i >= 0; i--) {
          const currentToken = tokens[i];

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
            const text = currentToken.content;
            const links = (cache[text] = cache[text] || match(text, matchers));

            // Now split string to nodes
            const nodes = [];
            let level = currentToken.level;
            let lastPos = 0;

            let token;
            for (let ln = 0; ln < links.length; ln++) {
              let fullUrl = state.md.normalizeLink(links[ln].url);
              if (!state.md.validateLink(fullUrl)) {
                continue;
              }

              if (links[ln].index < lastPos) {
                continue;
              }

              if (links[ln].index > lastPos) {
                token = new state.Token("text", "", 0);
                token.content = text.slice(lastPos, links[ln].index);
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
              token.content = links[ln].text;
              token.level = level;
              nodes.push(token);

              token = new state.Token("link_close", "a", -1);
              token.level = --level;
              token.markup = "linkify";
              token.info = "auto";
              nodes.push(token);

              lastPos = links[ln].index + links[ln].text.length;
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
