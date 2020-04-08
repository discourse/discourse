// see: https://github.com/markdown-it/markdown-it/issues/375
//
// we use a custom paragraph rule cause we have to signal when a
// link starts with a space, so we can bypass a onebox
// this is a freedom patch, so careful, may break on updates

function newline(state, silent) {
  var token,
    pmax,
    max,
    pos = state.pos;

  if (state.src.charCodeAt(pos) !== 0x0a /* \n */) {
    return false;
  }

  pmax = state.pending.length - 1;
  max = state.posMax;

  // '  \n' -> hardbreak
  // Lookup in pending chars is bad practice! Don't copy to other rules!
  // Pending string is stored in concat mode, indexed lookups will cause
  // convertion to flat mode.
  if (!silent) {
    if (pmax >= 0 && state.pending.charCodeAt(pmax) === 0x20) {
      if (pmax >= 1 && state.pending.charCodeAt(pmax - 1) === 0x20) {
        state.pending = state.pending.replace(/ +$/, "");
        token = state.push("hardbreak", "br", 0);
      } else {
        state.pending = state.pending.slice(0, -1);
        token = state.push("softbreak", "br", 0);
      }
    } else {
      token = state.push("softbreak", "br", 0);
    }
  }

  pos++;

  // skip heading spaces for next line
  while (pos < max && state.md.utils.isSpace(state.src.charCodeAt(pos))) {
    if (token) {
      token.leading_space = true;
    }
    pos++;
  }

  state.pos = pos;
  return true;
}

export function setup(helper) {
  helper.registerPlugin(md => {
    md.inline.ruler.at("newline", newline);
  });
}
