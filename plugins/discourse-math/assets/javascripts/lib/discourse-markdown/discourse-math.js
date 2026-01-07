const CHAR_CODES = {
  DOLLAR: 36,
  PERCENT: 37,
  BACKSLASH: 92,
  OPEN_BRACKET: 91,
  CLOSE_BRACKET: 93,
};

const MATH_TYPES = {
  TEX: "tex",
  ASCIIMATH: "asciimath",
};

const TOKEN_TYPES = {
  INLINE: "math_inline",
  BLOCK: "math_block",
};

const CSS_CLASSES = {
  MATH: "math",
  ASCIIMATH: "asciimath",
};

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

function addInlineMathToken(state, content, mathType) {
  const token = state.push(TOKEN_TYPES.INLINE, "", 0);
  token.content = content;
  token.meta = { mathType };
}

function addBlockMathToken(state, content) {
  const token = state.push(TOKEN_TYPES.BLOCK, "", 0);
  token.content = content;
  token.block = true;
}

function findClosingInlineDelimiter(src, start, posMax, delimiterCode) {
  for (let i = start; i < posMax; i++) {
    const code = src.charCodeAt(i);
    if (code === delimiterCode && !isEscaped(src, i)) {
      return i;
    }
  }
  return -1;
}

function isEscaped(src, index) {
  let backslashes = 0;
  let i = index - 1;
  while (i >= 0 && src.charCodeAt(i) === CHAR_CODES.BACKSLASH) {
    backslashes++;
    i--;
  }
  return backslashes % 2 === 1;
}

function math_input(state, silent, delimiterCode) {
  const pos = state.pos;
  const posMax = state.posMax;

  if (
    silent ||
    state.src.charCodeAt(pos) !== delimiterCode ||
    posMax < pos + 2
  ) {
    return false;
  }

  if (state.src.charCodeAt(pos + 1) === delimiterCode) {
    return false;
  }

  if (pos > 0) {
    const prev = state.src.charCodeAt(pos - 1);
    if (!isSafeBoundary(prev, delimiterCode, state.md)) {
      return false;
    }
    if (prev === delimiterCode) {
      return false;
    }
  }

  const found = findClosingInlineDelimiter(
    state.src,
    pos + 1,
    posMax,
    delimiterCode
  );

  if (found === -1) {
    return false;
  }

  if (found + 1 <= posMax) {
    const next = state.src.charCodeAt(found + 1);
    if (next && !isSafeBoundary(next, delimiterCode, state.md)) {
      return false;
    }
    if (next === delimiterCode) {
      return false;
    }
  }

  const data = state.src.slice(pos + 1, found);
  if (data.includes("\n")) {
    return false;
  }
  const mathType =
    delimiterCode === CHAR_CODES.DOLLAR ? MATH_TYPES.TEX : MATH_TYPES.ASCIIMATH;
  addInlineMathToken(state, data, mathType);
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
    while (j >= 0 && src.charCodeAt(j) === CHAR_CODES.BACKSLASH) {
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
  const pos = state.pos;
  const posMax = state.posMax;

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

  const data = state.src.slice(start, end);
  if (!data || data.includes("\n")) {
    return false;
  }

  addInlineMathToken(state, data, MATH_TYPES.TEX);
  state.pos = end + close.length;
  return true;
}

function inlineMath(state, silent) {
  return math_input(state, silent, CHAR_CODES.DOLLAR);
}

function inlineMathParen(state, silent) {
  return math_input_delimited(state, silent, "\\(", "\\)");
}

function asciiMath(state, silent) {
  return math_input(state, silent, CHAR_CODES.PERCENT);
}

function hasOnlyWhitespaceAfter(src, start, max, md) {
  for (let i = start; i < max; i++) {
    if (!md.utils.isSpace(src.charCodeAt(i))) {
      return false;
    }
  }
  return true;
}

function isDollarBlockMarker(state, start, max, md) {
  if (state.src.charCodeAt(start) !== CHAR_CODES.DOLLAR) {
    return false;
  }
  if (state.src.charCodeAt(start + 1) !== CHAR_CODES.DOLLAR) {
    return false;
  }
  return hasOnlyWhitespaceAfter(state.src, start + 2, max, md);
}

function isBracketBlockMarker(state, start, max, md) {
  if (state.src.charCodeAt(start) !== CHAR_CODES.BACKSLASH) {
    return false;
  }
  if (state.src.charCodeAt(start + 1) !== CHAR_CODES.OPEN_BRACKET) {
    return false;
  }
  return hasOnlyWhitespaceAfter(state.src, start + 2, max, md);
}

function isBracketBlockEnd(state, start, max, md) {
  if (state.src.charCodeAt(start) !== CHAR_CODES.BACKSLASH) {
    return false;
  }
  if (state.src.charCodeAt(start + 1) !== CHAR_CODES.CLOSE_BRACKET) {
    return false;
  }
  return hasOnlyWhitespaceAfter(state.src, start + 2, max, md);
}

function trySingleLineBlockMath(
  state,
  startLine,
  line,
  silent,
  enableLatexDelimiters
) {
  const patterns = [{ start: "$$", end: "$$" }];

  if (enableLatexDelimiters) {
    patterns.push({ start: "\\[", end: "\\]" });
  }

  for (const { start, end } of patterns) {
    if (
      line.startsWith(start) &&
      line.endsWith(end) &&
      line.length > start.length + end.length
    ) {
      if (silent) {
        return true;
      }

      const content = line.slice(start.length, -end.length).trim();
      if (!content) {
        return false;
      }

      addBlockMathToken(state, content);
      state.line = startLine + 1;
      return true;
    }
  }

  return null;
}

function findClosingBlockLine(state, startLine, endLine, isEndMarker) {
  let nextLine = startLine;

  for (;;) {
    nextLine++;

    if (nextLine >= endLine) {
      return { nextLine, closed: false };
    }

    const lineStart = state.bMarks[nextLine] + state.tShift[nextLine];
    const lineEnd = state.eMarks[nextLine];

    if (isEndMarker(state, lineStart, lineEnd, state.md)) {
      return { nextLine, closed: true };
    }
  }
}

function extractMultilineBlockContent(state, startLine, nextLine, closed) {
  const contentStart =
    state.bMarks[startLine + 1] + state.tShift[startLine + 1];
  const contentEnd = closed
    ? state.eMarks[nextLine - 1]
    : state.eMarks[nextLine];
  return state.src.slice(contentStart, contentEnd);
}

function processMultilineBlock(state, startLine, endLine, silent, isEndMarker) {
  if (silent) {
    return true;
  }

  const { nextLine, closed } = findClosingBlockLine(
    state,
    startLine,
    endLine,
    isEndMarker
  );
  const content = extractMultilineBlockContent(
    state,
    startLine,
    nextLine,
    closed
  );

  addBlockMathToken(state, content);
  state.line = closed ? nextLine + 1 : nextLine;

  return true;
}

function blockMath(state, startLine, endLine, silent) {
  const start = state.bMarks[startLine] + state.tShift[startLine];
  const max = state.eMarks[startLine];
  const enableLatexDelimiters =
    state.md.options.discourse.features.enable_latex_delimiters;
  const line = state.src.slice(start, max).trim();

  const singleLineResult = trySingleLineBlockMath(
    state,
    startLine,
    line,
    silent,
    enableLatexDelimiters
  );
  if (singleLineResult !== null) {
    return singleLineResult;
  }

  if (isDollarBlockMarker(state, start, max, state.md)) {
    return processMultilineBlock(
      state,
      startLine,
      endLine,
      silent,
      isDollarBlockMarker
    );
  }

  if (
    enableLatexDelimiters &&
    isBracketBlockMarker(state, start, max, state.md)
  ) {
    return processMultilineBlock(
      state,
      startLine,
      endLine,
      silent,
      isBracketBlockEnd
    );
  }

  return false;
}

export function setup(helper) {
  if (!helper.markdownIt) {
    return;
  }

  helper.allowList([
    `span.${CSS_CLASSES.MATH}`,
    `span.${CSS_CLASSES.ASCIIMATH}`,
    `div.${CSS_CLASSES.MATH}`,
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.math = siteSettings.discourse_math_enabled;
    opts.features.asciimath =
      siteSettings.discourse_math_enable_asciimath &&
      siteSettings.discourse_math_provider === "mathjax";
    opts.features.enable_latex_delimiters =
      siteSettings.discourse_math_enable_latex_delimiters;
  });

  helper.registerPlugin((md) => {
    if (md.options.discourse.features.math) {
      md.renderer.rules[TOKEN_TYPES.INLINE] = (tokens, idx) => {
        const token = tokens[idx];
        const mathType = token.meta?.mathType;
        const className =
          mathType === MATH_TYPES.ASCIIMATH
            ? CSS_CLASSES.ASCIIMATH
            : CSS_CLASSES.MATH;
        const escaped = md.utils.escapeHtml(token.content);
        return `<span class='${className}'>${escaped}</span>`;
      };

      md.renderer.rules[TOKEN_TYPES.BLOCK] = (tokens, idx) => {
        const token = tokens[idx];
        const escaped = md.utils.escapeHtml(token.content);
        return `<div class='${CSS_CLASSES.MATH}'>\n${escaped}\n</div>\n`;
      };

      if (md.options.discourse.features.asciimath) {
        md.inline.ruler.after("escape", CSS_CLASSES.ASCIIMATH, asciiMath);
      }
      if (md.options.discourse.features.enable_latex_delimiters) {
        md.inline.ruler.before("text", "math-paren", inlineMathParen);
      }
      md.inline.ruler.after("escape", CSS_CLASSES.MATH, inlineMath);
      md.block.ruler.after("code", CSS_CLASSES.MATH, blockMath, {
        alt: ["paragraph", "reference", "blockquote", "list"],
      });
    }
  });
}
