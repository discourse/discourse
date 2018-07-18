import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

function tokanizeBBCode(state, silent, ruler) {
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
      jump: 0
    });

    state.pos = pos + tagInfo.length;
    return true;
  }
}

function processBBCode(state, silent) {
  let i,
    startDelim,
    endDelim,
    token,
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

    token = state.tokens[startDelim.token];
    let tag, className;

    if (typeof tagInfo.rule.wrap === "function") {
      let content = "";
      for (let j = startDelim.token + 1; j < endDelim.token; j++) {
        let inner = state.tokens[j];
        if (inner.type === "text" && inner.meta !== "bbcode") {
          content += inner.content;
        }
      }
      tagInfo.rule.wrap(token, state.tokens[endDelim.token], tagInfo, content);
      continue;
    } else {
      let split = tagInfo.rule.wrap.split(".");
      tag = split[0];
      className = split.slice(1).join(" ");
    }

    token.type = "bbcode_" + tagInfo.tag + "_open";
    token.tag = tag;
    if (className) {
      token.attrs = [["class", className]];
    }
    token.nesting = 1;
    token.markup = token.content;
    token.content = "";

    token = state.tokens[endDelim.token];
    token.type = "bbcode_" + tagInfo.tag + "_close";
    token.tag = tag;
    token.nesting = -1;
    token.markup = token.content;
    token.content = "";
  }
  return false;
}

export function setup(helper) {
  helper.whiteList([
    "span.bbcode-b",
    "span.bbcode-i",
    "span.bbcode-u",
    "span.bbcode-s"
  ]);

  helper.registerOptions(opts => {
    opts.features["bbcode-inline"] = true;
  });

  helper.registerPlugin(md => {
    const ruler = md.inline.bbcode.ruler;

    md.inline.ruler.push("bbcode-inline", (state, silent) =>
      tokanizeBBCode(state, silent, ruler)
    );
    md.inline.ruler2.before("text_collapse", "bbcode-inline", processBBCode);

    ruler.push("code", {
      tag: "code",
      replace: function(state, tagInfo, content) {
        let token;
        token = state.push("code_inline", "code", 0);
        token.content = content;
        return true;
      }
    });

    const simpleUrlRegex = /^http[s]?:\/\//;
    ruler.push("url", {
      tag: "url",
      wrap: function(startToken, endToken, tagInfo, content) {
        const url = (tagInfo.attrs["_default"] || content).trim();

        if (simpleUrlRegex.test(url)) {
          startToken.type = "link_open";
          startToken.tag = "a";
          startToken.attrs = [["href", url], ["data-bbcode", "true"]];
          startToken.content = "";
          startToken.nesting = 1;

          endToken.type = "link_close";
          endToken.tag = "a";
          endToken.content = "";
          endToken.nesting = -1;
        } else {
          // just strip the bbcode tag
          endToken.content = "";
          startToken.content = "";

          // edge case, we don't want this detected as a onebox if auto linked
          // this ensures it is not stripped
          startToken.type = "html_inline";
        }

        return false;
      }
    });

    ruler.push("email", {
      tag: "email",
      replace: function(state, tagInfo, content) {
        let token;
        let email = tagInfo.attrs["_default"] || content;

        token = state.push("link_open", "a", 1);
        token.attrs = [["href", "mailto:" + email], ["data-bbcode", "true"]];

        token = state.push("text", "", 0);
        token.content = content;

        token = state.push("link_close", "a", -1);
        return true;
      }
    });

    ruler.push("image", {
      tag: "img",
      replace: function(state, tagInfo, content) {
        let token = state.push("image", "img", 0);
        token.attrs = [["src", content], ["alt", ""]];
        token.children = [];
        return true;
      }
    });

    ruler.push("bold", {
      tag: "b",
      wrap: "span.bbcode-b"
    });

    ruler.push("italic", {
      tag: "i",
      wrap: "span.bbcode-i"
    });

    ruler.push("underline", {
      tag: "u",
      wrap: "span.bbcode-u"
    });

    ruler.push("strike", {
      tag: "s",
      wrap: "span.bbcode-s"
    });
  });
}
