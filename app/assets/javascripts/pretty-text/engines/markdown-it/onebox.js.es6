function applyOnebox(state, silent) {
  if (silent || !state.tokens || state.tokens.length < 3) {
    return;
  }

  let i;
  for(i=1;i<state.tokens.length;i++) {
    let token = state.tokens[i];

    let prev = state.tokens[i-1];
    let prevAccepted =  prev.type === "paragraph_open" && prev.level === 0;

    if (token.type === "inline" && prevAccepted) {
      let j;
      for(j=0;j<token.children.length;j++){
        let child = token.children[j];

        if (child.type === "link_open") {

          // look behind for soft or hard break
          if (j > 0 && token.children[j-1].tag !== 'br') {
            continue;
          }

          // look ahead for soft or hard break
          let text = token.children[j+1];
          let close = token.children[j+2];
          let lookahead = token.children[j+3];

          if (lookahead && lookahead.tag !== 'br') {
            continue;
          }

          // check attrs only include a href
          let attrs = child["attrs"];

          if (!attrs || attrs.length !== 1 || attrs[0][0] !== "href") {
            continue;
          }

          // check text matches href
          if (text.type !== "text" || attrs[0][1] !== text.content) {
            continue;
          }

          if (!close || close.type !== "link_close") {
            continue;
          }

          // decorate...
          attrs.push(["class", "onebox"]);
        }
      }
    }
  }
}


export function setup(helper) {

  if (!helper.markdownIt) { return; }

  helper.registerPlugin(md => {
    md.core.ruler.after('linkify', 'onebox', applyOnebox);
  });
}
