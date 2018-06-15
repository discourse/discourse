// see: https://github.com/markdown-it/markdown-it/issues/375
//
// we use a custom paragraph rule cause we have to signal when a
// link starts with a space, so we can bypass a onebox
// this is a freedom patch, so careful, may break on updates
function paragraph(state, startLine /*, endLine*/) {
  var content,
    terminate,
    i,
    l,
    token,
    oldParentType,
    nextLine = startLine + 1,
    terminatorRules = state.md.block.ruler.getRules("paragraph"),
    endLine = state.lineMax,
    hasLeadingSpace = false;

  oldParentType = state.parentType;
  state.parentType = "paragraph";

  // jump line-by-line until empty one or EOF
  for (; nextLine < endLine && !state.isEmpty(nextLine); nextLine++) {
    // this would be a code block normally, but after paragraph
    // it's considered a lazy continuation regardless of what's there
    if (state.sCount[nextLine] - state.blkIndent > 3) {
      continue;
    }

    // quirk for blockquotes, this line should already be checked by that rule
    if (state.sCount[nextLine] < 0) {
      continue;
    }

    // Some tags can terminate paragraph without empty line.
    terminate = false;
    for (i = 0, l = terminatorRules.length; i < l; i++) {
      if (terminatorRules[i](state, nextLine, endLine, true)) {
        terminate = true;
        break;
      }
    }
    if (terminate) {
      break;
    }
  }

  // START CUSTOM CODE
  content = state.getLines(startLine, nextLine, state.blkIndent, false);

  i = 0;
  let contentLength = content.length;
  while (i < contentLength) {
    let chr = content.charCodeAt(i);
    if (chr === 0x0a) {
      hasLeadingSpace = false;
    } else if (state.md.utils.isWhiteSpace(chr)) {
      hasLeadingSpace = true;
    } else {
      break;
    }
    i++;
  }

  content = content.trim();
  // END CUSTOM CODE

  state.line = nextLine;

  token = state.push("paragraph_open", "p", 1);
  token.map = [startLine, state.line];
  // CUSTOM
  token.leading_space = hasLeadingSpace;

  token = state.push("inline", "", 0);
  token.content = content;
  token.map = [startLine, state.line];
  token.children = [];
  // CUSTOM
  token.leading_space = hasLeadingSpace;

  token = state.push("paragraph_close", "p", -1);

  state.parentType = oldParentType;
  return true;
}

export function setup(helper) {
  helper.registerPlugin(md => {
    md.block.ruler.at("paragraph", paragraph);
  });
}
