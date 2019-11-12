import { lookupCache } from "pretty-text/oneboxer-cache";
import { cachedInlineOnebox } from "pretty-text/inline-oneboxer";
import {
  INLINE_ONEBOX_LOADING_CSS_CLASS,
  INLINE_ONEBOX_CSS_CLASS
} from "pretty-text/context/inline-onebox-css-classes";

const ONEBOX = 1;
const INLINE = 2;

function isTopLevel(href) {
  let split = href.split(/https?:\/\/[^\/]+[\/?]/i);
  let hasExtra = split && split[1] && split[1].length > 0;
  return !hasExtra;
}

function applyOnebox(state, silent) {
  if (silent || !state.tokens) {
    return;
  }

  for (let i = 1; i < state.tokens.length; i++) {
    let token = state.tokens[i];
    let prev = state.tokens[i - 1];
    let mode =
      prev.type === "paragraph_open" && prev.level === 0 ? ONEBOX : INLINE;

    if (token.type === "inline") {
      let children = token.children;
      for (let j = 0; j < children.length - 2; j++) {
        let child = children[j];

        if (
          child.type === "link_open" &&
          child.markup === "linkify" &&
          child.info === "auto"
        ) {
          if (j > children.length - 3) {
            continue;
          }

          if (j === 0 && token.leading_space) {
            mode = INLINE;
          } else if (j > 0) {
            let prevSibling = children[j - 1];
            if (prevSibling.tag !== "br" || prevSibling.leading_space) {
              mode = INLINE;
            }
          }

          // look ahead for soft or hard break
          let text = children[j + 1];
          let close = children[j + 2];
          let lookahead = children[j + 3];

          if (lookahead && lookahead.tag !== "br") {
            mode = INLINE;
          }

          // check attrs only include a href
          let attrs = child.attrs;

          if (!attrs || attrs.length !== 1 || attrs[0][0] !== "href") {
            continue;
          }

          let href = attrs[0][1];

          // edge case ... what if this is not http or protocoless?
          if (!/^http|^\/\//i.test(href)) {
            continue;
          }

          // we already know text matches cause it is an auto link
          if (!close || close.type !== "link_close") {
            continue;
          }

          if (mode === ONEBOX) {
            // we already determined earlier that 0 0 was href
            let cached = lookupCache(attrs[0][1]);

            if (cached) {
              // replace link with 2 blank text nodes and inline html for onebox
              child.type = "html_raw";
              child.content = cached;
              child.inline = true;

              text.type = "html_raw";
              text.content = "";
              text.inline = true;

              close.type = "html_raw";
              close.content = "";
              close.inline = true;
            } else {
              // decorate...
              attrs.push(["class", "onebox"]);
              attrs.push(["target", "_blank"]);
            }
          } else if (mode === INLINE && !isTopLevel(href)) {
            const onebox = cachedInlineOnebox(href);

            if (onebox && onebox.title) {
              text.content = onebox.title;
              attrs.push(["class", INLINE_ONEBOX_CSS_CLASS]);
            } else if (!onebox) {
              attrs.push(["class", INLINE_ONEBOX_LOADING_CSS_CLASS]);
            }
          }
        }
      }
    }
  }
}

export function setup(helper) {
  helper.registerPlugin(md => {
    md.core.ruler.after("linkify", "onebox", applyOnebox);
  });
}
