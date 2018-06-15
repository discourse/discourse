// special handling for IMG tags on a line by themeselves
// we always have to handle it as so it is an inline
// see: https://talk.commonmark.org/t/newline-and-img-tags/2511

const REGEX = /^<img.*\\?>\s*$/i;

function rule(state, startLine, endLine) {
  var nextLine,
    token,
    lineText,
    pos = state.bMarks[startLine] + state.tShift[startLine],
    max = state.eMarks[startLine];

  // if it's indented more than 3 spaces, it should be a code block
  if (state.sCount[startLine] - state.blkIndent >= 4) {
    return false;
  }

  if (!state.md.options.html) {
    return false;
  }

  if (state.src.charCodeAt(pos) !== 0x3c /* < */) {
    return false;
  }
  let pos1 = state.src.charCodeAt(pos + 1);
  if (pos1 !== 73 /* I */ && pos1 !== 105 /* i */) {
    return false;
  }

  lineText = state.src.slice(pos, max);

  if (!REGEX.test(lineText)) {
    return false;
  }

  let lines = [];
  lines.push(lineText);

  nextLine = startLine + 1;
  for (; nextLine < endLine; nextLine++) {
    pos = state.bMarks[nextLine] + state.tShift[nextLine];
    max = state.eMarks[nextLine];
    lineText = state.src.slice(pos, max);

    if (lineText.trim() === "") {
      break;
    }

    if (!REGEX.test(lineText)) {
      break;
    }

    lines.push(lineText);
  }

  state.line = nextLine;
  let oldParentType = state.parentType;
  state.parentType = "paragraph";

  token = state.push("paragraph_open", "p", 1);
  token.map = [startLine, state.line];

  token = state.push("inline", "", 0);
  token.content = lines.join("\n");
  token.map = [startLine, state.line];
  token.children = [];

  token = state.push("paragraph_close", "p", -1);
  state.parentType = oldParentType;

  return true;
}

export function setup(helper) {
  helper.registerPlugin(md => {
    md.block.ruler.before("html_block", "html_img", rule, { alt: ["fence"] });
  });
}
