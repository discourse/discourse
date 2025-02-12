function hexColorRule(state, silent) {
  const start = state.pos;
  const src = state.src;

  const match = /^#[0-9A-Fa-f]{6}/.exec(src.slice(start));

  if (!match) {
    return false;
  }

  const token = state.push("hex_color", "", 0);
  token.content = match[0];

  state.pos += match[0].length;

  return true;
}

function hexColorRender(tokens, idx, options, env, self) {  
  const color = tokens[idx].content;
  return `<span>${color}</span>`;
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
