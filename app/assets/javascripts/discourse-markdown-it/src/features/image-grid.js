const gridRule = {
  tag: "grid",
  before(state) {
    let token = state.push("bbcode_open", "div", 1);
    token.attrs = [["class", "d-image-grid"]];
  },

  after(state) {
    state.push("bbcode_close", "div", -1);
  },
};

export function setup(helper) {
  helper.allowList(["div.d-image-grid"]);

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("grid", gridRule);
  });
}
