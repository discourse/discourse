// Only match [ ], [x], [X] - not empty [] to avoid offset drift when toggling
const REGEX = /\[([ xX])\]/gi;

function getClasses(str) {
  switch (str) {
    case "x":
      return "checked fa fa-square-check-o fa-fw";
    case "X":
      return "checked permanent fa fa-square-check fa-fw";
    case " ":
      return "fa fa-square-o fa-fw";
  }
}

function addCheckbox(result, match, state) {
  const classes = getClasses(match[1]);

  const checkOpenToken = new state.Token("check_open", "span", 1);
  checkOpenToken.attrs = [["class", `chcklst-box ${classes}`]];
  result.push(checkOpenToken);

  const checkCloseToken = new state.Token("check_close", "span", -1);
  result.push(checkCloseToken);
}

function applyCheckboxes(content, state) {
  let match;
  let result = null;
  let pos = 0;

  while ((match = REGEX.exec(content))) {
    if (match.index > pos) {
      result = result || [];
      const token = new state.Token("text", "", 0);
      token.content = content.slice(pos, match.index);
      result.push(token);
    }

    pos = match.index + match[0].length;

    result = result || [];
    addCheckbox(result, match, state);
  }

  if (result && pos < content.length) {
    const token = new state.Token("text", "", 0);
    token.content = content.slice(pos);
    result.push(token);
  }

  return result;
}

// Build a map of line number -> character offset in source
function buildLineOffsets(src) {
  const offsets = [0];
  for (let i = 0; i < src.length; i++) {
    if (src[i] === "\n") {
      offsets.push(i + 1);
    }
  }
  return offsets;
}

function processChecklist(state) {
  const src = state.src;
  const lineOffsets = buildLineOffsets(src);

  // Track search position for finding checkbox offsets
  let searchPos = 0;

  for (let j = 0; j < state.tokens.length; j++) {
    const blockToken = state.tokens[j];
    if (blockToken.type !== "inline") {
      continue;
    }

    // Update search position to start of this block's lines
    if (blockToken.map) {
      searchPos = Math.max(searchPos, lineOffsets[blockToken.map[0]] || 0);
    }

    let tokens = blockToken.children;
    let nesting = 0;

    // We scan from the end, to keep position when new tags are added.
    for (let i = tokens.length - 1; i >= 0; i--) {
      const token = tokens[i];
      nesting += token.nesting;

      if (token.type === "text" && nesting === 0) {
        const processed = applyCheckboxes(token.content, state);
        if (processed) {
          blockToken.children = tokens = state.md.utils.arrayReplaceAt(
            tokens,
            i,
            processed
          );
        }
      }
    }

    // Now assign offsets to checkbox tokens in this block
    // Track position by iterating through all tokens in order
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i];

      if (token.type === "code_inline") {
        // Skip past inline code in source (find content within backticks)
        // Search for the content preceded by backtick
        let idx = searchPos;
        while (idx < src.length) {
          const contentIdx = src.indexOf(token.content, idx);
          if (contentIdx === -1) {
            break;
          }
          // Check if preceded by backtick (inline code marker)
          if (contentIdx > 0 && src[contentIdx - 1] === "`") {
            // Advance past the closing backtick(s)
            let endIdx = contentIdx + token.content.length;
            while (endIdx < src.length && src[endIdx] === "`") {
              endIdx++;
            }
            searchPos = endIdx;
            break;
          }
          idx = contentIdx + 1;
        }
      } else if (token.type === "softbreak" || token.type === "hardbreak") {
        // Advance to next line
        const nlIdx = src.indexOf("\n", searchPos);
        if (nlIdx !== -1) {
          searchPos = nlIdx + 1;
        }
      } else if (token.type === "check_open") {
        // Find next checkbox in source from searchPos
        const regex = /\[([ xX])\]/g;
        regex.lastIndex = searchPos;

        let match;
        while ((match = regex.exec(src)) !== null) {
          const offset = match.index;

          // Skip if preceded by ! (image) or \ (escaped)
          if (
            offset > 0 &&
            (src[offset - 1] === "!" || src[offset - 1] === "\\")
          ) {
            continue;
          }

          // Found valid checkbox
          tokens[i].attrs.push(["data-chk-off", String(offset)]);
          searchPos = offset + match[0].length;
          break;
        }
      }
    }
  }
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.features["checklist"] = !!siteSettings.checklist_enabled;
  });

  helper.allowList([
    "span.chcklst-box fa fa-square-o fa-fw",
    "span.chcklst-box checked fa fa-square-check-o fa-fw",
    "span.chcklst-box checked permanent fa fa-square-check fa-fw",
    "span[data-chk-off]",
  ]);

  helper.registerPlugin((md) =>
    md.core.ruler.before("text_join", "checklist", processChecklist)
  );
}
