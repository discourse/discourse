import { applyDataAttributes } from "./bbcode-block";

const gridRule = {
  tag: "grid",
  before(state, tagInfo) {
    let token = state.push("bbcode_open", "div", 1);
    token.attrs = [["class", "d-image-grid"]];

    if (tagInfo?.attrs) {
      const { mode, aspect } = tagInfo.attrs;
      applyDataAttributes(token, { mode, aspect });
    }
  },

  after(state) {
    state.push("bbcode_close", "div", -1);
  },
};

export function setup(helper) {
  helper.allowList([
    "div.d-image-grid",
    "div.d-image-grid[data-mode]",
    "div.d-image-grid[data-aspect]",
  ]);

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("grid", gridRule);
  });
}
