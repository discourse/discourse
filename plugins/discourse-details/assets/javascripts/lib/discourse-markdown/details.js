const rule = {
  tag: "details",
  before(state, tagInfo) {
    const attrs = tagInfo.attrs;
    const details = state.push("bbcode_open", "details", 1);
    state.push("bbcode_open", "summary", 1);

    if (attrs.open === "") {
      details.attrs = [["open", ""]];
    }

    let token = state.push("text", "", 0);
    token.content = attrs["_default"] || "";

    state.push("bbcode_close", "summary", -1);
  },

  after(state) {
    state.push("bbcode_close", "details", -1);
  },
};

export function setup(helper) {
  helper.allowList([
    "summary",
    "summary[title]",
    "details",
    "details[open]",
    "details.elided",
  ]);

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("details", rule);
  });
}
