import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

const rule = {
  tag: "wrap",

  before(state, tagInfo) {
    const defaultAttrs = tagInfo.attrs._default || "";

    let parsed = parseBBCodeTag(
      "[wrap wrap=" + defaultAttrs + "]",
      0,
      defaultAttrs.length + 12
    );

    let token = state.push("bbcode_open", "div", 1);
    token.attrs = [["class", "d-wrap"]];

    const attributes = parsed.attrs || {};
    Object.keys(attributes).forEach(tag => {
      const value = state.md.utils.escapeHtml(attributes[tag]);
      tag = state.md.utils.escapeHtml(tag.replace(/[^a-z0-9\-]/g, ""));

      if (value && tag && tag.length > 1) {
        token.attrs.push([`data-${tag}`, value]);
      }
    });
  },

  after(state) {
    state.push("bbcode_close", "div", -1);
  }
};

export function setup(helper) {
  helper.registerPlugin(md => {
    md.block.bbcode.ruler.push("wraps", rule);
  });

  helper.whiteList(["div.d-wrap"]);
}
