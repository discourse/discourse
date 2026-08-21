const CONTENT_REGEX = /(?<![!\\])\[([ xX]?)\]/g;
const SRC_FALLBACK_REGEX = new RegExp(CONTENT_REGEX.source, "g");

function getClasses(char) {
  if (char === "x") {
    return "checked fa fa-square-check-o";
  }
  if (char === "X") {
    return "checked permanent fa fa-square-check";
  }
  return "fa fa-square-o";
}

function processChecklist(state) {
  const src = state.src;

  if (!src.includes("[")) {
    return;
  }

  const lineOffsets = [0];
  for (let i = 0; i < src.length; i++) {
    if (src[i] === "\n") {
      lineOffsets.push(i + 1);
    }
  }

  let convU16 = 0;
  let convCp = 0;
  const toCodepoint = (u16) => {
    if (u16 < convU16) {
      convU16 = 0;
      convCp = 0;
    }
    while (convU16 < u16) {
      const c = src.codePointAt(convU16);
      convU16 += c > 0xffff ? 2 : 1;
      convCp++;
    }
    return convCp;
  };

  let globalCursor = 0;

  for (const block of state.tokens) {
    if (block.type !== "inline") {
      continue;
    }

    let cursor, blockEnd;
    if (block.map) {
      cursor = lineOffsets[block.map[0]] ?? 0;
      blockEnd = lineOffsets[block.map[1]] ?? src.length;
    } else {
      cursor = globalCursor;
      blockEnd = src.length;
    }

    const replacements = [];
    let nesting = 0;

    const advance = (needle) => {
      if (!needle) {
        return;
      }
      const idx = src.indexOf(needle, cursor);
      if (idx !== -1 && idx < blockEnd) {
        cursor = idx + needle.length;
      }
    };

    for (let i = 0; i < block.children.length; i++) {
      const token = block.children[i];
      const renderable =
        token.type === "text" && nesting === 0 && token.content.includes("[");

      if (token.type === "text_special") {
        advance(token.markup);
      } else if (
        token.type === "code_inline" ||
        token.type === "html_inline" ||
        (token.type === "text" && !renderable)
      ) {
        advance(token.content);
      } else if (renderable) {
        let anchor = src.indexOf(token.content, cursor);
        if (anchor >= blockEnd) {
          anchor = -1;
        }

        const newTokens = [];
        let lastIdx = 0;
        let match;
        CONTENT_REGEX.lastIndex = 0;
        while ((match = CONTENT_REGEX.exec(token.content)) !== null) {
          let offset;
          if (anchor !== -1) {
            offset = anchor + match.index;
          } else {
            SRC_FALLBACK_REGEX.lastIndex = cursor;
            const srcMatch = SRC_FALLBACK_REGEX.exec(src);
            if (srcMatch && srcMatch.index < blockEnd) {
              offset = srcMatch.index;
              cursor = srcMatch.index + srcMatch[0].length;
            }
          }

          if (match.index > lastIdx) {
            const text = new state.Token("text", "", 0);
            text.content = token.content.slice(lastIdx, match.index);
            newTokens.push(text);
          }

          const checkbox = new state.Token("check_open", "span", 1);
          const isPermanent = match[1] === "X";
          checkbox.attrs = [["class", `chcklst-box ${getClasses(match[1])}`]];
          if (!isPermanent && offset !== undefined) {
            checkbox.attrs.push(["data-chk-off", String(toCodepoint(offset))]);
          }
          newTokens.push(checkbox);
          newTokens.push(new state.Token("check_close", "span", -1));

          lastIdx = match.index + match[0].length;
        }

        if (newTokens.length) {
          if (lastIdx < token.content.length) {
            const text = new state.Token("text", "", 0);
            text.content = token.content.slice(lastIdx);
            newTokens.push(text);
          }
          replacements.push({ index: i, newTokens });
        }
        if (anchor !== -1) {
          cursor = anchor + token.content.length;
        }
      }

      nesting += token.nesting;
    }

    for (let j = replacements.length - 1; j >= 0; j--) {
      block.children = state.md.utils.arrayReplaceAt(
        block.children,
        replacements[j].index,
        replacements[j].newTokens
      );
    }
    globalCursor = Math.max(globalCursor, cursor);
  }
}

export function setup(helper) {
  helper.registerOptions((opts, { checklist_enabled }) => {
    opts.features["checklist"] = !!checklist_enabled;
  });

  helper.allowList([
    "span.chcklst-stroked",
    "span.chcklst-box fa fa-square-o",
    "span.chcklst-box checked fa fa-square-check-o",
    "span.chcklst-box checked permanent fa fa-square-check",
    "span[data-chk-off]",
  ]);

  helper.registerPlugin((md) =>
    md.core.ruler.before("text_join", "checklist", processChecklist)
  );
}
