const SCALES = ["100", "75", "50"];

function isUpload(token) {
  return token.content.includes("upload://");
}

function hasMetadata(token) {
  return token.content.match(/(\d{1,4}x\d{1,4})/);
}

function appendMetaData(index, token) {
  const sizePart = token.content
    .split("|")
    .find(x => x.match(/\d{1,4}x\d{1,4}(,\s*\d{1,3}%)?/));
  let selectedScale =
    sizePart &&
    sizePart
      .split(",")
      .pop()
      .trim()
      .replace("%", "");

  const overwriteScale = !SCALES.find(scale => scale === selectedScale);
  if (overwriteScale) selectedScale = "100";

  token.attrs.push(["index-image", index]);
  token.attrs.push(["scale", selectedScale]);
}

function rule(state) {
  let currentIndex = 0;

  for (let i = 0; i < state.tokens.length; i++) {
    let blockToken = state.tokens[i];
    const blockTokenImage = blockToken.tag === "img";

    if (blockTokenImage && isUpload(blockToken) && hasMetadata(blockToken)) {
      appendMetaData(currentIndex, blockToken);
      currentIndex++;
    }

    if (!blockToken.children) continue;

    for (let j = 0; j < blockToken.children.length; j++) {
      let token = blockToken.children[j];
      const childrenImage = token.tag === "img";

      if (childrenImage && isUpload(blockToken) && hasMetadata(token)) {
        appendMetaData(currentIndex, token);
        currentIndex++;
      }
    }
  }
}

function buildScaleButton(selectedScale, scale) {
  const activeScaleClass = selectedScale === scale ? "active" : "";
  return (
    "<span class='scale-btn" +
    activeScaleClass +
    "' data-scale='" +
    scale +
    "'>" +
    scale +
    "%</span>"
  );
}

export function setup(helper) {
  const opts = helper.getOptions();
  if (opts.previewing) {
    helper.whiteList([
      "span.image-wrapper",
      "span.button-wrapper",
      "span[class=scale-btn]",
      "span[class=scale-btn active]",
      "span.separator",
      "span.scale-btn[data-scale]",
      "span.button-wrapper[data-image-index]"
    ]);

    helper.registerPlugin(md => {
      const oldRule = md.renderer.rules.image;

      md.renderer.rules.image = function(tokens, idx, options, env, slf) {
        const token = tokens[idx];
        const scaleIndex = token.attrIndex("scale");
        const imageIndex = token.attrIndex("index-image");

        if (scaleIndex !== -1) {
          var selectedScale = token.attrs[scaleIndex][1];
          var index = token.attrs[imageIndex][1];

          let result = "<span class='image-wrapper'>";
          result += oldRule(tokens, idx, options, env, slf);

          result +=
            "<span class='button-wrapper' data-image-index='" + index + "'>";

          result += SCALES.map(scale =>
            buildScaleButton(selectedScale, scale)
          ).join("<span class='separator'>&nbsp;•&nbsp;</span>");

          result += "</span></span>";

          return result;
        } else {
          return oldRule(tokens, idx, options, env, slf);
        }
      };

      md.core.ruler.after("upload-protocol", "resize-controls", rule);
    });
  }
}
