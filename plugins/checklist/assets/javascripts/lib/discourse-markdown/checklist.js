const CHECKBOX_REGEX = /(?<![!\\])\[([ xX])\]/g;

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

  // Line offsets to skip fenced code blocks
  const lineOffsets = [0];
  for (let i = 0; i < src.length; i++) {
    if (src[i] === "\n") {
      lineOffsets.push(i + 1);
    }
  }

  let searchPos = 0;

  for (const block of state.tokens) {
    if (block.type !== "inline") {
      continue;
    }

    // Jump past fenced code blocks
    if (block.map) {
      searchPos = Math.max(searchPos, lineOffsets[block.map[0]] || 0);
    }

    const replacements = [];
    let nesting = 0;

    for (let i = 0; i < block.children.length; i++) {
      const token = block.children[i];

      if (token.type === "code_inline") {
        // Advance past inline code in source
        const start = src.indexOf("`", searchPos);
        if (start !== -1) {
          const end = src.indexOf("`", start + 1 + token.content.length);
          if (end !== -1) {
            searchPos = end + 1;
          }
        }
      } else if (token.type === "text" && nesting === 0) {
        const newTokens = [];
        let lastIdx = 0;

        CHECKBOX_REGEX.lastIndex = 0;
        let match;
        while ((match = CHECKBOX_REGEX.exec(token.content)) !== null) {
          // Find offset in source (lookbehind handles escapes/images)
          CHECKBOX_REGEX.lastIndex = searchPos;
          const srcMatch = CHECKBOX_REGEX.exec(src);
          const offset = srcMatch?.index;
          if (srcMatch) {
            searchPos = srcMatch.index + 3;
          }

          if (match.index > lastIdx) {
            const text = new state.Token("text", "", 0);
            text.content = token.content.slice(lastIdx, match.index);
            newTokens.push(text);
          }

          const checkbox = new state.Token("check_open", "span", 1);
          const isPermanent = match[1] === "X";
          checkbox.attrs = [["class", `chcklst-box ${getClasses(match[1])}`]];
          if (!isPermanent) {
            checkbox.attrs.push(["data-chk-off", String(offset)]);
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
      }

      nesting += token.nesting;
    }

    // Apply replacements in reverse to preserve indices
    for (let j = replacements.length - 1; j >= 0; j--) {
      block.children = state.md.utils.arrayReplaceAt(
        block.children,
        replacements[j].index,
        replacements[j].newTokens
      );
    }
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
