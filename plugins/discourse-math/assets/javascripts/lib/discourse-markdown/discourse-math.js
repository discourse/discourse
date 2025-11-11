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

function inlineMath(state, silent) {
  return math_input(state, silent, 36 /* $ */);
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

function blockMath(state, startLine, endLine, silent) {
  let start = state.bMarks[startLine] + state.tShift[startLine],
    max = state.eMarks[startLine];

  if (!isBlockMarker(state, start, max, state.md)) {
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
  });

  helper.registerPlugin((md) => {
    if (md.options.discourse.features.math) {
      if (md.options.discourse.features.asciimath) {
        md.inline.ruler.after("escape", "asciimath", asciiMath);
      }
      md.inline.ruler.after("escape", "math", inlineMath);
      md.block.ruler.after("code", "math", blockMath, {
        alt: ["paragraph", "reference", "blockquote", "list"],
      });
    }
  });
}
