import {
  createWatchedWordRegExp,
  toWatchedWord,
} from "discourse-common/utils/watched-words";

const MAX_MATCHES = 100;

function isLinkOpen(str) {
  return /^<a[>\s]/i.test(str);
}

function isLinkClose(str) {
  return /^<\/a\s*>/i.test(str);
}

function findAllMatches(text, matchers) {
  const matches = [];

  for (const { word, pattern, replacement, link } of matchers) {
    if (matches.length >= MAX_MATCHES) {
      break;
    }

    if (word.test(text)) {
      for (const match of text.matchAll(pattern)) {
        matches.push({
          index: match.index + match[0].indexOf(match[1]),
          text: match[1],
          replacement,
          link,
        });

        if (matches.length >= MAX_MATCHES) {
          break;
        }
      }
    }
  }

  return matches.sort((a, b) => a.index - b.index);
}

// We need this to load after mentions and hashtags which are priority 0
export const priority = 1;

const NONE = 0;
const MENTION = 1;
const HASHTAG_LINK = 2;
const HASHTAG_SPAN = 3;
const HASHTAG_ICON_SPAN = 4;

export function setup(helper) {
  const opts = helper.getOptions();

  helper.registerPlugin((md) => {
    const matchers = [];

    if (md.options.discourse.watchedWordsReplace) {
      Object.entries(md.options.discourse.watchedWordsReplace).forEach(
        ([regexpString, options]) => {
          const word = toWatchedWord({ [regexpString]: options });

          matchers.push({
            word: new RegExp(options.word, options.case_sensitive ? "" : "i"),
            pattern: createWatchedWordRegExp(word),
            replacement: options.replacement,
            link: false,
          });
        }
      );
    }

    if (md.options.discourse.watchedWordsLink) {
      Object.entries(md.options.discourse.watchedWordsLink).forEach(
        ([regexpString, options]) => {
          const word = toWatchedWord({ [regexpString]: options });

          matchers.push({
            word: new RegExp(options.word, options.case_sensitive ? "" : "i"),
            pattern: createWatchedWordRegExp(word),
            replacement: options.replacement,
            link: true,
          });
        }
      );
    }

    if (matchers.length === 0) {
      return;
    }

    const cache = new Map();

    md.core.ruler.push("watched-words", (state) => {
      for (let j = 0, l = state.tokens.length; j < l; j++) {
        if (state.tokens[j].type !== "inline") {
          continue;
        }

        let tokens = state.tokens[j].children;

        let htmlLinkLevel = 0;

        // We scan once to mark tokens that must be skipped because they are
        // mentions or hashtags
        let lastType = NONE;
        let currentType = NONE;
        for (let i = 0; i < tokens.length; ++i) {
          const currentToken = tokens[i];

          if (currentToken.type === "mention_open") {
            lastType = MENTION;
          } else if (
            (currentToken.type === "link_open" ||
              currentToken.type === "span_open") &&
            currentToken.attrs &&
            currentToken.attrs.some(
              (attr) =>
                attr[0] === "class" &&
                (attr[1] === "hashtag" ||
                  attr[1] === "hashtag-cooked" ||
                  attr[1] === "hashtag-raw")
            )
          ) {
            lastType =
              currentToken.type === "link_open" ? HASHTAG_LINK : HASHTAG_SPAN;
          }

          if (
            currentToken.type === "span_open" &&
            currentToken.attrs &&
            currentToken.attrs.some(
              (attr) =>
                attr[0] === "class" && attr[1] === "hashtag-icon-placeholder"
            )
          ) {
            currentType = HASHTAG_ICON_SPAN;
          }

          if (lastType !== NONE) {
            currentToken.skipReplace = true;
          }

          if (
            (lastType === MENTION && currentToken.type === "mention_close") ||
            (lastType === HASHTAG_LINK && currentToken.type === "link_close") ||
            (lastType === HASHTAG_SPAN &&
              currentToken.type === "span_close" &&
              currentType !== HASHTAG_ICON_SPAN)
          ) {
            lastType = NONE;
          }
        }

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

          // Skip content of mentions or hashtags
          if (currentToken.skipReplace) {
            continue;
          }

          if (currentToken.type === "text") {
            const text = currentToken.content;

            let matches;
            if (cache.has(text)) {
              matches = cache.get(text);
            } else {
              matches = findAllMatches(text, matchers);
              cache.set(text, matches);
            }

            // Now split string to nodes
            const nodes = [];
            let level = currentToken.level;
            let lastPos = 0;

            let token;
            for (let ln = 0; ln < matches.length; ln++) {
              if (matches[ln].index < lastPos) {
                continue;
              }

              if (matches[ln].index > lastPos) {
                token = new state.Token("text", "", 0);
                token.content = text.slice(lastPos, matches[ln].index);
                token.level = level;
                nodes.push(token);
              }

              if (matches[ln].link) {
                const url = state.md.normalizeLink(matches[ln].replacement);
                if (htmlLinkLevel === 0 && state.md.validateLink(url)) {
                  token = new state.Token("link_open", "a", 1);
                  token.attrs = [["href", url]];
                  if (opts.discourse.previewing) {
                    token.attrs.push(["data-word", ""]);
                  }
                  token.level = level++;
                  token.markup = "linkify";
                  token.info = "auto";
                  nodes.push(token);

                  token = new state.Token("text", "", 0);
                  token.content = matches[ln].text;
                  token.level = level;
                  nodes.push(token);

                  token = new state.Token("link_close", "a", -1);
                  token.level = --level;
                  token.markup = "linkify";
                  token.info = "auto";
                  nodes.push(token);
                }
              } else {
                token = new state.Token("text", "", 0);
                token.content = matches[ln].replacement;
                token.level = level;
                nodes.push(token);
              }

              lastPos = matches[ln].index + matches[ln].text.length;
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
