function hexColorRule(state, silent) {

}

export function setup(helper) {

};

export function setup(helper) {
  helper.registerPlugin((md) => {
    md.inline.ruler.at("hex-color", hexColorRule);
  });
}
