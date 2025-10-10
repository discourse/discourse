export function setup(helper) {
  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("test", {
      tag: "test",
      before(state) {
        let token = state.push("test", "div", 1);
        token.attrs = [["class", "d-test"]];
      },

      after(state) {
        state.push("test", "div", -1);
      },
    });
  });
}
