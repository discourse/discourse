import { applyDataAttributes } from "./bbcode-block";

const VALID_MODES = new Set(["grid", "carousel"]);

const gridRule = {
  tag: "grid",
  before(state, tagInfo) {
    let token = state.push("bbcode_open", "div", 1);
    token.attrs = [["class", "d-image-grid"]];

    if (tagInfo?.attrs) {
      let { mode } = tagInfo.attrs;
      if (mode && !VALID_MODES.has(mode)) {
        mode = "grid";
      }
      applyDataAttributes(token, { mode });
    }
  },

  after(state) {
    state.push("bbcode_close", "div", -1);
  },
};

export function setup(helper) {
  helper.allowList(["div.d-image-grid", "div.d-image-grid[data-mode]"]);

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("grid", gridRule);
  });
}
