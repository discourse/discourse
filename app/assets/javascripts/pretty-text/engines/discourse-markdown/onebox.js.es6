import { lookupCache } from 'pretty-text/oneboxer';

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

        if (child.type === "link_open" && child.markup === 'linkify' && child.info === 'auto') {

          if (j === 0 && token.leading_space) {
            continue;
          } else if (j > 0) {

            let prevSibling = token.children[j-1];

            if (prevSibling.tag !== 'br' || prevSibling.leading_space) {
              continue;
            }
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

          // edge case ... what if this is not http or protocoless?
          if (!/^http|^\/\//i.test(attrs[0][1])) {
            continue;
          }

          // we already know text matches cause it is an auto link
          if (!close || close.type !== "link_close") {
            continue;
          }

          // we already determined earlier that 0 0 was href
          let cached = lookupCache(attrs[0][1]);

          if (cached) {
            // replace link with 2 blank text nodes and inline html for onebox
            child.type = 'html_raw';
            child.content = cached;
            child.inline = true;

            text.type = 'html_raw';
            text.content = '';
            text.inline = true;

            close.type = 'html_raw';
            close.content = '';
            close.inline = true;

          } else {
            // decorate...
            attrs.push(["class", "onebox"]);
            attrs.push(["target", "_blank"]);
          }
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
