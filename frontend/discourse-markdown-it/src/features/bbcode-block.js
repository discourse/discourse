import { camelCaseToDash } from "discourse/lib/case-converter";

let isWhiteSpace, escapeHtml;

export function applyDataAttributes(token, attributes, defaultName) {
  const { _default, ...attrs } = attributes;

  if (_default && defaultName) {
    attrs[defaultName] = _default;
  }

  for (let key of Object.keys(attrs).sort()) {
    const value = escapeHtml(attrs[key]);
    key = camelCaseToDash(key.replace(/[^a-z0-9-]/gi, ""));
    if (value && key && key.length > 1) {
      token.attrSet(`data-${key}`, value);
    }
  }
}

function trailingSpaceOnly(src, start, max) {
  for (let i = start; i < max; i++) {
    const code = src.charCodeAt(i);
    if (code === 0x0a) {
      return true;
    }
    if (!isWhiteSpace(code)) {
      return false;
    }
  }

  return true;
}

// Most common quotation marks.
// More can be found at https://en.wikipedia.org/wiki/Quotation_mark
// Keep in sync with plugins/chat/lib/chat/transcript_service.rb
export const QUOTATION_MARKS = [
  `""`,
  `''`,
  `«»`,
  `“”`,
  `””`,
  `‘’`,
  `„“`,
  `‚’`,
  `‹›`,
];

const QUOTATION_MARKS_PATTERN = new RegExp(
  `[${QUOTATION_MARKS.join("")}]`,
  "g"
);

export const stripQuotationMarks = (value) =>
  (value || "").replace(QUOTATION_MARKS_PATTERN, "");

const QUOTATION_MARKS_NO_MATCH = QUOTATION_MARKS.map(
  ([a, b]) => `${a}[^${b}]+${b}`
).join("|");

const QUOTATION_MARKS_WITH_MATCH = QUOTATION_MARKS.map(
  ([a, b]) => `${a}([^${b}]+)${b}`
).join("|");

// Easiest case is the closing tag which never has any attributes
const BBCODE_CLOSING_TAG_REGEXP = /^\[\/([-\w]+)\]/i;

// Old case where we supported attributes without quotation marks
// The value class already accepts leading whitespace.
const BBCODE_QUOTE_OR_DETAILS_TAG_REGEXP = new RegExp(
  `^\\[(quote|details)=([^${QUOTATION_MARKS.join("")}].+?)\\]`,
  "i"
);

// This is used to match a **valid** opening tag
// NOTE: it does not match the closing bracket "]" because it makes the regexp too slow
// due to the backtracking. So we check for the "]" manually.
const BBCODE_TAG_REGEXP = new RegExp(
  `^\\[(?:(?:[-\\w]+(?:=(?:${QUOTATION_MARKS_NO_MATCH}|[^\\s\\]]+))?)+\\s*)+`,
  "i"
);

// This is used to parse attributes of the form key=value
// Where value might have some quotation marks
const BBCODE_ATTR_REGEXP = new RegExp(
  `([-\\w]+)(?:=(?:${QUOTATION_MARKS_WITH_MATCH}|([^\\s\\]]+)))?`,
  "gi"
);

export function parseBBCodeTag(src, start, max, multiline) {
  let m;
  const text = src.slice(start, max);

  // CASE 1 - closing tag
  m = BBCODE_CLOSING_TAG_REGEXP.exec(text);

  if (m && m[0] && m[1]) {
    if (multiline && !trailingSpaceOnly(src, start + m[0].length, max)) {
      return null;
    }

    return {
      tag: m[1].toLowerCase(),
      closing: true,
      length: m[0].length,
    };
  }

  // CASE 2 - [quote=...] or [details=...] tag (without quotes)
  m = BBCODE_QUOTE_OR_DETAILS_TAG_REGEXP.exec(text);

  if (m && m[0] && m[1] && m[2]) {
    if (multiline && !trailingSpaceOnly(src, start + m[0].length, max)) {
      return null;
    }

    return {
      tag: m[1],
      length: m[0].length,
      attrs: { _default: m[2] },
    };
  }

  // CASE 3 - regular opening tag
  m = BBCODE_TAG_REGEXP.exec(text);
  const bbcode = m ? m[0] : null;

  if (!bbcode) {
    return null;
  }

  if (text.length <= bbcode.length || text[bbcode.length] !== "]") {
    return null;
  }

  const r = {};

  while ((m = BBCODE_ATTR_REGEXP.exec(bbcode))) {
    const [, key, ...v] = m;
    const value = v.find(Boolean);

    if (!key) {
      return null;
    }

    if (!r.tag) {
      r.tag = key.toLowerCase();
      r.length = bbcode.length + 1;
      if (m.index === 1) {
        r.attrs = {};
        if (value) {
          r.attrs["_default"] = value.trim();
        }
      } else {
        return null;
      }
    } else if (r.attrs) {
      r.attrs[key] = value?.trim() || "";
    } else {
      return null;
    }
  }

  if (r.tag) {
    if (multiline && !trailingSpaceOnly(src, start + bbcode.length + 1, max)) {
      return null;
    }
    return r;
  }

  return null;
}

// Matches every block bbcode open tag in [fromLine, endLine) to its closing
// tag in a single forward pass (respecting nesting). This lets findBlockCloseTag
// answer each open tag with an O(1) lookup instead of rescanning the remaining
// document for every tag, which made cooking quadratic on unclosed tags.
function buildBlockCloseTagMatches(state, fromLine, endLine) {
  const matches = new Map(); // open line -> close tag info
  const stacks = new Map(); // tag -> array of open line numbers
  let reachableEnd = endLine;

  for (let line = fromLine; line < endLine; line++) {
    const start = state.bMarks[line] + state.tShift[line];
    const max = state.eMarks[line];

    if (start < max && state.sCount[line] < state.blkIndent) {
      // A non-empty line with negative indent stops the search, so no tag
      // opened before it can close at or past it. Stopping here rather than
      // walking the rest of the enclosing range keeps the pass proportional to
      // the region a single lookup can reach - nested tokenize calls (list
      // items, block quotes) are handed the whole enclosing endLine.
      reachableEnd = line;
      break;
    }

    // bbcode tag [ === 91
    if (91 !== state.src.charCodeAt(start)) {
      continue;
    }

    if (state.sCount[line] - state.blkIndent >= 4) {
      // bbcode indented 4 or more spaces is treated as code, not a tag
      continue;
    }

    const tag = parseBBCodeTag(state.src, start, max, true);

    if (!tag) {
      continue;
    }

    if (tag.closing) {
      const stack = stacks.get(tag.tag);
      if (stack && stack.length > 0) {
        tag.line = line;
        tag.block = true;
        matches.set(stack.pop(), tag);
      }
    } else {
      let stack = stacks.get(tag.tag);
      if (!stack) {
        stack = [];
        stacks.set(tag.tag, stack);
      }
      stack.push(line);
    }
  }

  return { matches, endLine: reachableEnd };
}

function findBlockCloseTag(state, openTag, startLine, endLine) {
  const openLine = startLine - 1;

  let cache = state.bbcodeBlockCloseTags;
  if (!cache || openLine < cache.fromLine || openLine >= cache.endLine) {
    const built = buildBlockCloseTagMatches(state, openLine, endLine);

    cache = {
      fromLine: openLine,
      endLine: Math.max(built.endLine, openLine + 1),
      matches: built.matches,
    };
    state.bbcodeBlockCloseTags = cache;
  }

  const closeTag = cache.matches.get(openLine);

  // unclosed bbcode block should not be autoclosed by the end of document, and
  // a close tag outside the current (possibly nested) range does not apply.
  if (!closeTag || closeTag.tag !== openTag.tag || closeTag.line >= endLine) {
    return;
  }

  return closeTag;
}

// markdown-it rewrites the per-line offsets (bMarks/tShift/sCount) in place for
// the content of block quotes and lists and then re-parses those same lines, so
// a close tag map built for one nesting level describes different lines in the
// next. Scoping the map to a single `tokenize` call - during which the offsets
// are stable - keeps the lookup linear without serving stale matches.
function scopeBlockCloseTagCache(md) {
  const tokenize = md.block.tokenize;

  md.block.tokenize = function (state, startLine, endLine) {
    const parentCache = state.bbcodeBlockCloseTags;
    state.bbcodeBlockCloseTags = null;

    try {
      return tokenize.call(this, state, startLine, endLine);
    } finally {
      state.bbcodeBlockCloseTags = parentCache;
    }
  };
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
  let nextLine,
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

  // If an inline close tag is found and there's content after it on the same line,
  // let the inline processor handle it instead of block processing
  if (!closeTag.block && closeTag.start + closeTag.length < max) {
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
      content = state.getLines(startLine + 1, nextLine, 0, false);
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
  helper.registerPlugin((md) => {
    isWhiteSpace = md.utils.isWhiteSpace;
    escapeHtml = md.utils.escapeHtml;

    scopeBlockCloseTagCache(md);

    md.block.bbcode.ruler.push("excerpt", {
      tag: "excerpt",
      wrap: "div.excerpt",
    });

    md.block.bbcode.ruler.push("code", {
      tag: "code",
      replace(state, tagInfo, content) {
        let token = state.push("fence", "code", 0);
        token.content = content;
        return true;
      },
    });

    md.block.ruler.after(
      "fence",
      "bbcode",
      (state, startLine, endLine, silent) =>
        applyBBCode(state, startLine, endLine, silent, md),
      { alt: ["paragraph", "reference", "blockquote", "list"] }
    );
  });
}
