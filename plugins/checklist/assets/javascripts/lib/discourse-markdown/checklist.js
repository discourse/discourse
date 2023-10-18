const REGEX = /\[(\s?|x|X)\]/g;

function getClasses(str) {
  switch (str) {
    case "x":
      return "checked fa fa-check-square-o fa-fw";
    case "X":
      return "checked permanent fa fa-check-square fa-fw";
    default:
      return "fa fa-square-o fa-fw";
  }
}

function addCheckbox(result, content, match, state) {
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
    addCheckbox(result, content, match, state);
  }

  if (result && pos < content.length) {
    const token = new state.Token("text", "", 0);
    token.content = content.slice(pos);
    result.push(token);
  }

  return result;
}

function processChecklist(state) {
  let i,
    j,
    l,
    tokens,
    token,
    blockTokens = state.tokens,
    nesting = 0;

  for (j = 0, l = blockTokens.length; j < l; j++) {
    if (blockTokens[j].type !== "inline") {
      continue;
    }
    tokens = blockTokens[j].children;

    // We scan from the end, to keep position when new tags are added.
    // Use reversed logic in links start/end match
    for (i = tokens.length - 1; i >= 0; i--) {
      token = tokens[i];

      nesting += token.nesting;

      if (token.type === "text" && nesting === 0) {
        const processed = applyCheckboxes(token.content, state);
        if (processed) {
          blockTokens[j].children = tokens = state.md.utils.arrayReplaceAt(
            tokens,
            i,
            processed
          );
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
    "span.chcklst-stroked",
    "span.chcklst-box fa fa-square-o fa-fw",
    "span.chcklst-box checked fa fa-check-square-o fa-fw",
    "span.chcklst-box checked permanent fa fa-check-square fa-fw",
  ]);

  helper.registerPlugin((md) =>
    md.core.ruler.push("checklist", processChecklist)
  );
}
