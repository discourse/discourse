function hexColorRule(state, silent) {
  const start = state.pos;
  const src = state.src;

  const match = /^#[0-9A-Fa-f]{6}/.exec(src.slice(start));

  if (!match) {
    return false;
  }

  state.pos += match[0].length;

  return true;
}

function hexColorRender() {
  return `<span>Hex Color</span>`;
}



export function setup(helper) {
  helper.registerOptions(() => {
    return {
      features: {
        "hex-color": true
      }
    };
  });

  helper.registerPlugin((md) => {
    md.inline.ruler.push("hex_color", hexColorRule);
    md.renderer.rules["hex_color"] = hexColorRender;
  });
}
