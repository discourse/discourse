import { cachedInlineOnebox } from 'pretty-text/inline-oneboxer';

function applyInlineOnebox(state, silent) {
  if (silent || !state.tokens) {
    return;
  }

  for (let i=1; i<state.tokens.length; i++) {
    let token = state.tokens[i];

    if (token.type === "inline") {
      let children = token.children;
      for (let j=0; j<children.length-2; j++) {
        let child = children[j];
        if (child.type === "link_open" && child.markup === 'linkify' && child.info === 'auto') {

          if (j > children.length-3) {
            continue;
          }

          let text = children[j+1];
          let close = children[j+2];

          // check attrs only include a href
          let attrs = child.attrs;
          if (!attrs || attrs.length !== 1 || attrs[0][0] !== "href") {
            continue;
          }

          let href = attrs[0][1];
          if (!/^http|^\/\//i.test(href)) {
            continue;
          }

          // we already know text matches cause it is an auto link
          if (!close || close.type !== "link_close") {
            continue;
          }

          // link must be the same as the href
          if (!text || text.content !== href) {
            continue;
          }

          // check for href
          let onebox = cachedInlineOnebox(href);

          let options = state.md.options.discourse;
          if (options.lookupInlineOnebox) {
            onebox = options.lookupInlineOnebox(href);
          }

          if (onebox) {
            text.content = onebox.title;
          } else if (state.md.options.discourse.previewing) {
            attrs.push(["class", "inline-onebox-loading"]);
          }
        }
      }
    }
  }
}

export function setup(helper) {
  helper.registerPlugin(md => {
    md.core.ruler.after('onebox', 'inline-onebox', applyInlineOnebox);
  });
}
