const rule = {
  tag: "details",
  before: function(state, tagInfo) {
    const attrs = tagInfo.attrs;
    state.push("bbcode_open", "details", 1);
    state.push("bbcode_open", "summary", 1);

    let token = state.push("text", "", 0);
    token.content = attrs["_default"] || "";

    state.push("bbcode_close", "summary", -1);
  },

  after: function(state) {
    state.push("bbcode_close", "details", -1);
  }
};

export function setup(helper) {
  helper.whiteList([
    "summary",
    "summary[title]",
    "details",
    "details[open]",
    "details.elided"
  ]);

  helper.registerPlugin(md => {
    md.block.bbcode.ruler.push("details", rule);
  });
}
