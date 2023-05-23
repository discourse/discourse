import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

function tokenizeBBCode(state, silent, ruler) {
  let pos = state.pos;

  // 91 = [
  if (silent || state.src.charCodeAt(pos) !== 91) {
    return false;
  }

  const tagInfo = parseBBCodeTag(state.src, pos, state.posMax);

  if (!tagInfo) {
    return false;
  }

  let rule, i;

  let ruleInfo = ruler.getRuleForTag(tagInfo.tag);
  if (!ruleInfo) {
    return false;
  }
  rule = ruleInfo.rule;

  if (rule.replace) {
    // special handling for replace
    // we pass raw contents to callback so we simply need to greedy match to end tag
    if (tagInfo.closing) {
      return false;
    }

    let closeTag = "[/" + tagInfo.tag + "]";
    let found = false;

    for (
      i = state.pos + tagInfo.length;
      i <= state.posMax - closeTag.length;
      i++
    ) {
      if (
        state.src.charCodeAt(pos) === 91 &&
        state.src.slice(i, i + closeTag.length).toLowerCase() === closeTag
      ) {
        found = true;
        break;
      }
    }

    if (!found) {
      return false;
    }

    let content = state.src.slice(state.pos + tagInfo.length, i);

    if (rule.replace(state, tagInfo, content)) {
      state.pos = i + closeTag.length;
      return true;
    } else {
      return false;
    }
  } else {
    tagInfo.rule = rule;

    if (tagInfo.closing && state.tokens.at(-1)?.meta === "bbcode") {
      state.push("text", "", 0);
    }

    let token = state.push("text", "", 0);
    token.content = state.src.slice(pos, pos + tagInfo.length);
    token.meta = "bbcode";

    state.delimiters.push({
      bbInfo: tagInfo,
      marker: "bb" + tagInfo.tag,
      open: !tagInfo.closing,
      close: !!tagInfo.closing,
      token: state.tokens.length - 1,
      level: state.level,
      end: -1,
    });

    state.pos = pos + tagInfo.length;
    return true;
  }
}

function processBBCode(state, silent) {
  let i,
    startDelim,
    endDelim,
    tagInfo,
    delimiters = state.delimiters,
    max = delimiters.length;

  if (silent) {
    return;
  }

  for (i = 0; i < max - 1; i++) {
    startDelim = delimiters[i];
    tagInfo = startDelim.bbInfo;

    if (!tagInfo) {
      continue;
    }

    if (startDelim.end === -1) {
      continue;
    }

    endDelim = delimiters[startDelim.end];

    let tag, className;

    const startToken = state.tokens[startDelim.token];
    const endToken = state.tokens[endDelim.token];

    if (typeof tagInfo.rule.wrap === "function") {
      let content = "";
      for (let j = startDelim.token + 1; j < endDelim.token; j++) {
        let inner = state.tokens[j];
        if (inner.type === "text" && inner.meta !== "bbcode") {
          content += inner.content;
        }
      }
      tagInfo.rule.wrap(startToken, endToken, tagInfo, content, state);
      continue;
    } else {
      let split = tagInfo.rule.wrap.split(".");
      tag = split[0];
      className = split.slice(1).join(" ");
    }

    startToken.type = "bbcode_" + tagInfo.tag + "_open";
    startToken.tag = tag;
    if (className) {
      startToken.attrs = [["class", className]];
    }
    startToken.nesting = 1;
    startToken.markup = startToken.content;
    startToken.content = "";

    endToken.type = "bbcode_" + tagInfo.tag + "_close";
    endToken.tag = tag;
    endToken.nesting = -1;
    endToken.markup = startToken.content;
    endToken.content = "";
  }
  return false;
}

export function setup(helper) {
  helper.allowList([
    "span.bbcode-b",
    "span.bbcode-i",
    "span.bbcode-u",
    "span.bbcode-s",
  ]);

  helper.registerOptions((opts) => {
    opts.features["bbcode-inline"] = true;
  });

  helper.registerPlugin((md) => {
    const ruler = md.inline.bbcode.ruler;

    md.inline.ruler.push("bbcode-inline", (state, silent) =>
      tokenizeBBCode(state, silent, ruler)
    );
    md.inline.ruler2.before("fragments_join", "bbcode-inline", processBBCode);

    ruler.push("code", {
      tag: "code",
      replace(state, tagInfo, content) {
        let token;
        token = state.push("code_inline", "code", 0);
        token.content = content;
        return true;
      },
    });

    const simpleUrlRegex = /^https?:\/\//;
    ruler.push("url", {
      tag: "url",

      replace(state, tagInfo, content) {
        let token;

        // we need to tokenize the content and reinsert tokens in the stream
        // this is because we need to support nested bbcode
        let tokens = [];
        md.inline.parse(content, state.md, state.env, tokens);

        let url = tagInfo.attrs["_default"];

        if (!url) {
          // try to find the actual url in the tokens
          for (let i = 0; i < tokens.length; i++) {
            token = tokens[i];
            // nested linkify or link, just pick it
            if (token.type === "link_open") {
              for (let j = 0; j < token.attrs.length; j++) {
                if (token.attrs[j][0] === "href") {
                  url = token.attrs[j][1];
                  break;
                }
              }
              if (url) {
                break;
              }
            }
            if (token.type === "text") {
              url = token.content;
              break;
            }
          }
        }

        if (md.linkify) {
          let match = null;

          // linkify has trouble with strings containing spaces, so just ban
          // them outright
          if (url && !url.includes(" ")) {
            match = md.linkify.matchAtStart(url);
            if (!match) {
              match = md.linkify.matchAtStart("https://" + url);
            }
          }

          if (match) {
            url = match.url;
          } else {
            url = null;
          }
        } else if (!url.match(simpleUrlRegex)) {
          url = "https://" + url;
        }

        if (url) {
          token = state.push("link_open", "a", 0);
          token.attrs = ["href", url];
          token.attrs = [
            ["href", url],
            ["data-bbcode", "true"],
          ];
          token.content = "";
          token.nesting = 1;
        }

        for (let i = 0; i < tokens.length; i++) {
          token = tokens[i];
          if (token.type === "link_open" || token.type === "link_close") {
            // linkify nested tokens, do nothing
          } else {
            state.tokens.push(token);
          }
        }

        if (url) {
          token = state.push("link_close", "a", 0);
          token.nesting = -1;
          token.content = "";
        }

        return true;
      },
    });

    ruler.push("email", {
      tag: "email",
      replace(state, tagInfo, content) {
        let token;
        const email = tagInfo.attrs["_default"] || content;

        token = state.push("link_open", "a", 1);
        token.attrs = [
          ["href", "mailto:" + email],
          ["data-bbcode", "true"],
        ];

        token = state.push("text", "", 0);
        token.content = content;

        state.push("link_close", "a", -1);
        return true;
      },
    });

    ruler.push("image", {
      tag: "img",
      replace(state, tagInfo, content) {
        let token = state.push("image", "img", 0);
        token.attrs = [
          ["src", content],
          ["alt", ""],
        ];
        token.children = [];
        return true;
      },
    });

    ruler.push("bold", {
      tag: "b",
      wrap: "span.bbcode-b",
    });

    ruler.push("italic", {
      tag: "i",
      wrap: "span.bbcode-i",
    });

    ruler.push("underline", {
      tag: "u",
      wrap: "span.bbcode-u",
    });

    ruler.push("strike", {
      tag: "s",
      wrap: "span.bbcode-s",
    });
  });
}
