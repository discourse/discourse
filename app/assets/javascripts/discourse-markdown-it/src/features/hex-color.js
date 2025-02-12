function hexColorRule(state, silent) {
  const start = state.pos;
  const src = state.src;

  const match = /^#[0-9A-Fa-f]{6}/.exec(src.slice(start));
  return match;
}

export function setup(helper) {

};

export function setup(helper) {
  helper.registerPlugin((md) => {
    md.inline.ruler.at("hex-color", hexColorRule);
  });
}
