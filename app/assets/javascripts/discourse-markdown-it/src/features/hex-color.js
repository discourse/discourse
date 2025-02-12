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
  return `<span class="hex-color" style="background-color: ${color};"></span>${color}`;
}



export function setup(helper) {
  helper.allowList(["span.hex-color"]);

  helper.allowList({
    custom(tag, name, value) {
    
      if (tag === "span" && name === "style") {      
        return value.startsWith("background-color:");
      }
      return false;
    }
  });

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
