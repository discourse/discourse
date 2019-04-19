import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

function addWrapper(buffer, matches, state) {
  let token;

  let parsed = parseBBCodeTag(
    "[wrap wrap" + matches[1] + "]",
    0,
    matches[1].length + 11
  );

  token = new state.Token("div_open", "div", 1);
  token.attrs = [["class", "d-wrap"]];

  const attributes = parsed.attrs || {};
  const content = attributes.content;
  delete attributes.content;

  Object.keys(attributes).forEach(tag => {
    const value = state.md.utils.escapeHtml(attributes[tag]);
    tag = state.md.utils.escapeHtml(tag);
    token.attrs.push([`data-${tag}`, value]);
  });

  buffer.push(token);

  if (content) {
    token = new state.Token("text", "", 0);
    token.content = content;
    buffer.push(token);
  }

  token = new state.Token("div_close", "div", -1);
  buffer.push(token);
}

export function setup(helper) {
  helper.whiteList(["div.d-wrap"]);

  helper.registerPlugin(md => {
    const rule = {
      matcher: /\[wrap(=.+?)\]/,
      onMatch: addWrapper
    };

    md.core.textPostProcess.ruler.push("d-wrap", rule);
  });
}
