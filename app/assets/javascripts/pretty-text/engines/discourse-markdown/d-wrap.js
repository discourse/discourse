import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

const WRAP_CLASS = "d-wrap";

function parseAttributes(tagInfo) {
  const attributes = tagInfo.attrs._default || "";

  return (
    parseBBCodeTag(`[wrap wrap=${attributes}]`, 0, attributes.length + 12)
      .attrs || {}
  );
}

function camelCaseToDash(str) {
  return str.replace(/([a-zA-Z])(?=[A-Z])/g, "$1-").toLowerCase();
}

function applyDataAttributes(token, state, attributes) {
  Object.keys(attributes).forEach(tag => {
    const value = state.md.utils.escapeHtml(attributes[tag]);
    tag = camelCaseToDash(
      state.md.utils.escapeHtml(tag.replace(/[^A-Za-z\-0-9]/g, ""))
    );

    if (value && tag && tag.length > 1) {
      token.attrs.push([`data-${tag}`, value]);
    }
  });
}

const blockRule = {
  tag: "wrap",

  before(state, tagInfo) {
    let token = state.push("wrap_open", "div", 1);
    token.attrs = [["class", WRAP_CLASS]];

    applyDataAttributes(token, state, parseAttributes(tagInfo));
  },

  after(state) {
    state.push("wrap_close", "div", -1);
  }
};

const inlineRule = {
  tag: "wrap",

  replace(state, tagInfo, content) {
    let token = state.push("wrap_open", "span", 1);
    token.attrs = [["class", WRAP_CLASS]];

    applyDataAttributes(token, state, parseAttributes(tagInfo));

    if (content) {
      token = state.push("text", "", 0);
      token.content = content;
    }

    token = state.push("wrap_close", "span", -1);
    return true;
  }
};

export function setup(helper) {
  helper.registerPlugin(md => {
    md.inline.bbcode.ruler.push("inline-wrap", inlineRule);
    md.block.bbcode.ruler.push("block-wrap", blockRule);
  });

  helper.whiteList([`div.${WRAP_CLASS}`, `span.${WRAP_CLASS}`, "span[data-*]"]);
}
