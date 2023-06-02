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
  helper.registerOptions((opts, siteSettings) => {
    opts.enableGrid = !!siteSettings.experimental_post_image_grid;
  });

  helper.allowList(["div.d-image-grid"]);

  helper.registerPlugin((md) => {
    if (!md.options.discourse.enableGrid) {
      return;
    }

    md.block.bbcode.ruler.push("grid", gridRule);
  });
}
