import { applyDataAttributes } from "./bbcode-block";

const WRAP_CLASS = "d-wrap";

const blockRule = {
  tag: "wrap",

  before(state, tagInfo) {
    let token = state.push("wrap_open", "div", 1);
    token.attrs = [["class", WRAP_CLASS]];
    applyDataAttributes(token, tagInfo.attrs, "wrap");
  },

  after(state) {
    state.push("wrap_close", "div", -1);
  },
};

const inlineRule = {
  tag: "wrap",

  replace(state, tagInfo, content) {
    let token = state.push("wrap_open", "span", 1);
    token.attrs = [["class", WRAP_CLASS]];
    applyDataAttributes(token, tagInfo.attrs, "wrap");

    if (content) {
      token = state.push("text", "", 0);
      token.content = content;
    }

    state.push("wrap_close", "span", -1);

    return true;
  },
};

export function setup(helper) {
  helper.registerPlugin((md) => {
    md.inline.bbcode.ruler.push("inline-wrap", inlineRule);
    md.block.bbcode.ruler.push("block-wrap", blockRule);
  });

  helper.allowList([`div.${WRAP_CLASS}`, `span.${WRAP_CLASS}`, "span[data-*]"]);
}
