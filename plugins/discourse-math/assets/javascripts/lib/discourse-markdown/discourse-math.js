// inspired by https://github.com/classeur/markdown-it-mathjax/blob/master/markdown-it-mathjax.js
//
//
//

const additionalPunctuation = [
  // Chinese and Japanese punctuation
  0x3001, // 、
  0x3002, // 。

  // Full-width punctuation used in East Asian languages
  0xff0c, // ，
  0xff1a, // ：
  0xff1b, // ；
  0xff0e, // ．
  0xff1f, // ？
  0xff01, // ！

  // Arabic punctuation
  0x060c, // ،
  0x061b, // ؛
  0x061f, // ؟

  // Thai punctuation
  0x0e2f, // ฯ
];

function isSafeBoundary(character_code, delimiter_code, md) {
  if (character_code === delimiter_code) {
    return false;
  }

  if (md.utils.isWhiteSpace(character_code)) {
    return true;
  }

  if (md.utils.isMdAsciiPunct(character_code)) {
    return true;
  }

  if (md.utils.isPunctChar(character_code)) {
    return true;
  }

  if (additionalPunctuation.includes(character_code)) {
    return true;
  }

  return false;
}

function math_input(state, silent, delimiter_code) {
  let pos = state.pos,
    posMax = state.posMax;

  if (
    silent ||
    state.src.charCodeAt(pos) !== delimiter_code ||
    posMax < pos + 2
  ) {
    return false;
  }

  // too short
  if (state.src.charCodeAt(pos + 1) === delimiter_code) {
    return false;
  }

  if (pos > 0) {
    let prev = state.src.charCodeAt(pos - 1);
    if (!isSafeBoundary(prev, delimiter_code, state.md)) {
      return false;
    }
  }

  let found;
  for (let i = pos + 1; i < posMax; i++) {
    let code = state.src.charCodeAt(i);
    if (code === delimiter_code && state.src.charCodeAt(i - 1) !== 92 /* \ */) {
      found = i;
      break;
    }
  }

  if (!found) {
    return false;
  }

  if (found + 1 <= posMax) {
    let next = state.src.charCodeAt(found + 1);
    if (next && !isSafeBoundary(next, delimiter_code, state.md)) {
      return false;
    }
  }

  let data = state.src.slice(pos + 1, found);
  let token = state.push("html_raw", "", 0);

  const escaped = state.md.utils.escapeHtml(data);
  let math_class = delimiter_code === 36 ? "'math'" : "'asciimath'";
  token.content = `<span class=${math_class}>${escaped}</span>`;
  state.pos = found + 1;
  return true;
}

function findClosingDelimiter(src, start, close) {
  const closeLength = close.length;

  for (let i = start; i <= src.length - closeLength; i++) {
    if (src.slice(i, i + closeLength) !== close) {
      continue;
    }

    let backslashes = 0;
    let j = i - 1;
    while (j >= 0 && src.charCodeAt(j) === 92 /* \ */) {
      backslashes++;
      j--;
    }

    if (backslashes % 2 === 0) {
      return i;
    }
  }

  return -1;
}

function math_input_delimited(state, silent, open, close) {
  let pos = state.pos;
  let posMax = state.posMax;

  if (silent || posMax < pos + open.length) {
    return false;
  }

  if (state.src.slice(pos, pos + open.length) !== open) {
    return false;
  }

  const start = pos + open.length;
  const end = findClosingDelimiter(state.src, start, close);

  if (end === -1) {
    return false;
  }

  let data = state.src.slice(start, end);
  if (!data) {
    return false;
  }

  let token = state.push("html_raw", "", 0);
  token.content = `<span class='math'>${state.md.utils.escapeHtml(data)}</span>`;
  state.pos = end + close.length;
  return true;
}

function inlineMath(state, silent) {
  return math_input(state, silent, 36 /* $ */);
}

function inlineMathParen(state, silent) {
  return math_input_delimited(state, silent, "\\(", "\\)");
}

function asciiMath(state, silent) {
  return math_input(state, silent, 37 /* % */);
}

function isBlockMarker(state, start, max, md) {
  if (state.src.charCodeAt(start) !== 36 /* $ */) {
    return false;
  }

  start++;

  if (state.src.charCodeAt(start) !== 36 /* $ */) {
    return false;
  }

  start++;

  // ensure we only have newlines after our $$
  for (let i = start; i < max; i++) {
    if (!md.utils.isSpace(state.src.charCodeAt(i))) {
      return false;
    }
  }

  return true;
}

function isBracketBlockMarker(state, start, max, md) {
  if (state.src.charCodeAt(start) !== 92 /* \ */) {
    return false;
  }

  if (state.src.charCodeAt(start + 1) !== 91 /* [ */) {
    return false;
  }

  start += 2;

  // ensure we only have newlines after our \[
  for (let i = start; i < max; i++) {
    if (!md.utils.isSpace(state.src.charCodeAt(i))) {
      return false;
    }
  }

  return true;
}

function isBracketBlockEnd(state, start, max, md) {
  if (state.src.charCodeAt(start) !== 92 /* \ */) {
    return false;
  }

  if (state.src.charCodeAt(start + 1) !== 93 /* ] */) {
    return false;
  }

  start += 2;

  for (let i = start; i < max; i++) {
    if (!md.utils.isSpace(state.src.charCodeAt(i))) {
      return false;
    }
  }

  return true;
}

function blockMath(state, startLine, endLine, silent) {
  let start = state.bMarks[startLine] + state.tShift[startLine],
    max = state.eMarks[startLine];

  const strict = state.md.options.discourse.features.strict_mathjax_markdown;
  const line = state.src.slice(start, max).trim();

  if (
    !strict &&
    line.startsWith("$$") &&
    line.endsWith("$$") &&
    line.length > 4
  ) {
    if (silent) {
      return true;
    }

    const content = line.slice(2, -2).trim();
    if (!content) {
      return false;
    }

    let token = state.push("html_raw", "", 0);
    token.content = `<div class='math'>\n${state.md.utils.escapeHtml(
      content
    )}\n</div>\n`;
    state.line = startLine + 1;
    return true;
  }

  if (
    !strict &&
    line.startsWith("\\[") &&
    line.endsWith("\\]") &&
    line.length > 4
  ) {
    if (silent) {
      return true;
    }

    const content = line.slice(2, -2).trim();
    if (!content) {
      return false;
    }

    let token = state.push("html_raw", "", 0);
    token.content = `<div class='math'>\n${state.md.utils.escapeHtml(
      content
    )}\n</div>\n`;
    state.line = startLine + 1;
    return true;
  }

  if (!isBlockMarker(state, start, max, state.md)) {
    if (!strict && isBracketBlockMarker(state, start, max, state.md)) {
      if (silent) {
        return true;
      }

      let nextLine = startLine;
      let closed = false;
      for (;;) {
        nextLine++;

        if (nextLine >= endLine) {
          break;
        }

        if (
          isBracketBlockEnd(
            state,
            state.bMarks[nextLine] + state.tShift[nextLine],
            state.eMarks[nextLine],
            state.md
          )
        ) {
          closed = true;
          break;
        }
      }

      let token = state.push("html_raw", "", 0);

      let endContent = closed
        ? state.eMarks[nextLine - 1]
        : state.eMarks[nextLine];
      let content = state.src.slice(
        state.bMarks[startLine + 1] + state.tShift[startLine + 1],
        endContent
      );

      token.content = `<div class='math'>\n${state.md.utils.escapeHtml(
        content
      )}\n</div>\n`;

      state.line = closed ? nextLine + 1 : nextLine;

      return true;
    }

    return false;
  }

  if (silent) {
    return true;
  }

  let nextLine = startLine;
  let closed = false;
  for (;;) {
    nextLine++;

    // unclosed $$ is considered math
    if (nextLine >= endLine) {
      break;
    }

    if (
      isBlockMarker(
        state,
        state.bMarks[nextLine] + state.tShift[nextLine],
        state.eMarks[nextLine],
        state.md
      )
    ) {
      closed = true;
      break;
    }
  }

  let token = state.push("html_raw", "", 0);

  let endContent = closed ? state.eMarks[nextLine - 1] : state.eMarks[nextLine];
  let content = state.src.slice(
    state.bMarks[startLine + 1] + state.tShift[startLine + 1],
    endContent
  );

  const escaped = state.md.utils.escapeHtml(content);
  token.content = `<div class='math'>\n${escaped}\n</div>\n`;

  state.line = closed ? nextLine + 1 : nextLine;

  return true;
}

export function setup(helper) {
  if (!helper.markdownIt) {
    return;
  }

  helper.registerOptions((opts, siteSettings) => {
    opts.features.math = siteSettings.discourse_math_enabled;
    opts.features.asciimath = siteSettings.discourse_math_enable_asciimath;
    opts.features.strict_mathjax_markdown =
      siteSettings.strict_mathjax_markdown;
  });

  helper.registerPlugin((md) => {
    if (md.options.discourse.features.math) {
      if (md.options.discourse.features.asciimath) {
        md.inline.ruler.after("escape", "asciimath", asciiMath);
      }
      if (!md.options.discourse.features.strict_mathjax_markdown) {
        md.inline.ruler.after("escape", "math-paren", inlineMathParen);
      }
      md.inline.ruler.after("escape", "math", inlineMath);
      md.block.ruler.after("code", "math", blockMath, {
        alt: ["paragraph", "reference", "blockquote", "list"],
      });
    }
  });
}
