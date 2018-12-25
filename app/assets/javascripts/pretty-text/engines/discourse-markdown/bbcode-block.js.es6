let isWhiteSpace;

function trailingSpaceOnly(src, start, max) {
  let i;
  for (i = start; i < max; i++) {
    let code = src.charCodeAt(i);
    if (code === 0x0a) {
      return true;
    }
    if (!isWhiteSpace(code)) {
      return false;
    }
  }

  return true;
}

const ATTR_REGEX = /^\s*=(.+)$|((([a-z0-9]*)\s*)=)(["“”'].*?["“”']|\S+)/gi;

// parse a tag [test a=1 b=2] to a data structure
// {tag: "test", attrs={a: "1", b: "2"}
export function parseBBCodeTag(src, start, max, multiline) {
  let i;
  let tag;
  let attrs = {};
  let closed = false;
  let length = 0;
  let closingTag = false;

  // closing tag
  if (src.charCodeAt(start + 1) === 47) {
    closingTag = true;
    start += 1;
  }

  for (i = start + 1; i < max; i++) {
    let letter = src[i];
    if (
      !((letter >= "a" && letter <= "z") || (letter >= "A" && letter <= "Z"))
    ) {
      break;
    }
  }

  tag = src.slice(start + 1, i);

  if (!tag) {
    return;
  }

  if (closingTag) {
    if (src[i] === "]") {
      if (multiline && !trailingSpaceOnly(src, i + 1, max)) {
        return;
      }

      tag = tag.toLowerCase();

      return { tag, length: tag.length + 3, closing: true };
    }
    return;
  }

  for (; i < max; i++) {
    let letter = src[i];

    if (letter === "]") {
      closed = true;
      break;
    }
  }

  if (closed) {
    length = i - start + 1;

    let raw = src.slice(start + tag.length + 1, i);

    // trivial parser that is going to have to be rewritten at some point
    if (raw) {
      let match, key, val;

      while ((match = ATTR_REGEX.exec(raw))) {
        if (match[1]) {
          key = "_default";
        } else {
          key = match[4];
        }

        val = match[1] || match[5];

        if (val) {
          val = val.trim();
          val = val.replace(/^["'“”](.*)["'“”]$/, "$1");
          attrs[key] = val;
        }
      }
    }

    if (multiline && !trailingSpaceOnly(src, start + length, max)) {
      return;
    }

    tag = tag.toLowerCase();

    return { tag, attrs, length };
  }
}

function findBlockCloseTag(state, openTag, startLine, endLine) {
  let nesting = 0,
    line = startLine - 1,
    start,
    closeTag,
    max;

  for (;;) {
    line++;
    if (line >= endLine) {
      // unclosed bbcode block should not be autoclosed by end of document.
      return;
    }

    start = state.bMarks[line] + state.tShift[line];
    max = state.eMarks[line];

    if (start < max && state.sCount[line] < state.blkIndent) {
      // non-empty line with negative indent should stop the list:
      // - ```
      //  test
      break;
    }

    // bbcode close [ === 91
    if (91 !== state.src.charCodeAt(start)) {
      continue;
    }

    if (state.sCount[line] - state.blkIndent >= 4) {
      // closing bbcode less than 4 spaces
      continue;
    }

    closeTag = parseBBCodeTag(state.src, start, max, true);

    if (closeTag && closeTag.closing && closeTag.tag === openTag.tag) {
      if (nesting === 0) {
        closeTag.line = line;
        closeTag.block = true;
        break;
      }
      nesting--;
    }

    if (closeTag && !closeTag.closing && closeTag.tag === openTag.tag) {
      nesting++;
    }

    closeTag = null;
  }

  return closeTag;
}

function findInlineCloseTag(state, openTag, start, max) {
  let closeTag;
  let possibleTag = false;

  for (let j = max - 1; j > start; j--) {
    if (!possibleTag) {
      if (state.src.charCodeAt(j) === 93 /* ] */) {
        possibleTag = true;
        continue;
      }
      if (!isWhiteSpace(state.src.charCodeAt(j))) {
        break;
      }
    } else {
      if (state.src.charCodeAt(j) === 91 /* [ */) {
        closeTag = parseBBCodeTag(state.src, j, max);
        if (!closeTag || closeTag.tag !== openTag.tag || !closeTag.closing) {
          closeTag = null;
        } else {
          closeTag.start = j;
          break;
        }
      }
    }
  }

  return closeTag;
}

function applyBBCode(state, startLine, endLine, silent, md) {
  var nextLine,
    oldParent,
    oldLineMax,
    rule,
    start = state.bMarks[startLine] + state.tShift[startLine],
    initial = start,
    max = state.eMarks[startLine];

  // [ === 91
  if (91 !== state.src.charCodeAt(start)) {
    return false;
  }

  let info = parseBBCodeTag(state.src, start, max);

  if (!info || info.closing) {
    return false;
  }

  let ruleInfo = md.block.bbcode.ruler.getRuleForTag(info.tag);
  if (!ruleInfo) {
    return false;
  }

  rule = ruleInfo.rule;

  // Since start is found, we can report success here in validation mode
  if (silent) {
    return true;
  }

  // Search for the end of the block
  nextLine = startLine;

  // We might have a single inline bbcode

  let closeTag = findInlineCloseTag(state, info, start + info.length, max);

  if (!closeTag) {
    if (!trailingSpaceOnly(state.src, start + info.length, max)) {
      return false;
    }
    closeTag = findBlockCloseTag(state, info, nextLine + 1, endLine);
  }

  if (!closeTag) {
    return false;
  }

  nextLine = closeTag.line || startLine;

  oldParent = state.parentType;
  oldLineMax = state.lineMax;

  // this will prevent lazy continuations from ever going past our end marker
  // which can happen if we are parsing a bbcode block
  state.lineMax = nextLine;

  if (rule.replace) {
    let content;

    if (startLine === nextLine) {
      content = state.src.slice(start + info.length, closeTag.start);
    } else {
      content = state.src.slice(
        state.bMarks[startLine + 1],
        state.eMarks[nextLine - 1]
      );
    }

    if (!rule.replace.call(this, state, info, content)) {
      return false;
    }
  } else {
    if (rule.before) {
      rule.before.call(
        this,
        state,
        info,
        state.src.slice(initial, initial + info.length + 1)
      );
    }

    let wrapTag;
    if (rule.wrap) {
      let token;

      if (typeof rule.wrap === "function") {
        token = new state.Token("wrap_bbcode", "div", 1);
        token.level = state.level + 1;

        if (!rule.wrap(token, info)) {
          return false;
        }

        state.tokens.push(token);
        state.level = token.level;
        wrapTag = token.tag;
      } else {
        let split = rule.wrap.split(".");
        wrapTag = split[0];
        let className = split.slice(1).join(" ");

        token = state.push("wrap_bbcode", wrapTag, 1);

        if (className) {
          token.attrs = [["class", className]];
        }
      }
    }

    let lastToken = state.tokens[state.tokens.length - 1];
    lastToken.map = [startLine, nextLine];

    if (closeTag.block) {
      state.md.block.tokenize(state, startLine + 1, nextLine);
    } else {
      let token = state.push("paragraph_open", "p", 1);
      token.map = [startLine, startLine];

      token = state.push("inline", "", 0);
      token.children = [];
      token.map = [startLine, startLine];
      token.content = state.src.slice(start + info.length, closeTag.start);

      state.push("paragraph_close", "p", -1);
    }

    if (rule.wrap) {
      state.push("wrap_bbcode", wrapTag, -1);
    }

    if (rule.after) {
      rule.after.call(
        this,
        state,
        lastToken,
        state.src.slice(start - 2, start + closeTag.length - 1)
      );
    }
  }

  state.parentType = oldParent;
  state.lineMax = oldLineMax;
  state.line = nextLine + 1;

  return true;
}

export function setup(helper) {
  helper.registerPlugin(md => {
    const ruler = md.block.bbcode.ruler;

    ruler.push("excerpt", {
      tag: "excerpt",
      wrap: "div.excerpt"
    });

    ruler.push("code", {
      tag: "code",
      replace: function(state, tagInfo, content) {
        let token;
        token = state.push("fence", "code", 0);
        token.content = content;
        return true;
      }
    });

    isWhiteSpace = md.utils.isWhiteSpace;
    md.block.ruler.after(
      "fence",
      "bbcode",
      (state, startLine, endLine, silent) => {
        return applyBBCode(state, startLine, endLine, silent, md);
      },
      { alt: ["paragraph", "reference", "blockquote", "list"] }
    );
  });
}
