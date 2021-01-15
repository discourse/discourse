function replaceArrows(state) {
  for (let i = 0; i < state.tokens.length; i++) {
    let token = state.tokens[i];

    if (token.type !== "inline") {
      continue;
    }

    const arrowsRegexp = /-->|<--|->|<-/;
    if (arrowsRegexp.test(token.content)) {
      for (let ci = 0; ci < token.children.length; ci++) {
        let child = token.children[ci];

        if (child.type === "text") {
          if (arrowsRegexp.test(child.content)) {
            child.content = child.content
              .replace(/(^|\s)-{1,2}>(\s|$)/gm, "\u0020\u2192\u0020")
              .replace(/(^|\s)<-{1,2}(\s|$)/gm, "\u0020\u2190\u0020");
          }
        }
      }
    }
  }
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    if (md.options.typographer) {
      md.core.ruler.before("replacements", "typographer-arrow", replaceArrows);
    }
  });
}
