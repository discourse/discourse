const SCALES = ["100", "75", "50"];

function isUpload(token) {
  return token.content.includes("upload://");
}

function hasMetadata(token) {
  return !!token.content
    .split("|")
    .find((part) => /^\d{1,4}x\d{1,4}(,\s*\d{1,3}%)?$/.test(part));
}

function appendMetaData(index, token) {
  const sizePart = token.content
    .split("|")
    .find((x) => x.match(/\d{1,4}x\d{1,4}(,\s*\d{1,3}%)?/));
  let selectedScale =
    sizePart && sizePart.split(",").pop().trim().replace("%", "");

  const overwriteScale = !SCALES.find((scale) => scale === selectedScale);
  if (overwriteScale) {
    selectedScale = "100";
  }

  token.attrs.push(["data-image-index", index]);
  token.attrs.push(["data-scale", selectedScale]);
}

// Count here, as the preview can drop images and can't show which were grouped.
function appendRunLength(tokens) {
  const first = tokens[0];

  if (first?.tag === "img" && first.attrIndex("data-image-index") !== -1) {
    first.attrs.push([
      "data-image-run",
      tokens.filter((token) => token.type === "image").length,
    ]);
  }
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

    if (!blockToken.children) {
      continue;
    }

    for (let j = 0; j < blockToken.children.length; j++) {
      let token = blockToken.children[j];
      const childrenImage = token.tag === "img";

      if (childrenImage && isUpload(blockToken) && hasMetadata(token)) {
        appendMetaData(currentIndex, token);
        currentIndex++;
      }
    }

    appendRunLength(blockToken.children);
  }

  appendRunLength(state.tokens);
}

// We need this to load after `upload-protocol` which is priority 0
export const priority = 1;

export function setup(helper) {
  const opts = helper.getOptions();
  if (opts.previewing) {
    helper.allowList([
      "img[data-image-index]",
      "img[data-image-run]",
      "img[data-scale]",
    ]);

    helper.registerPlugin((md) => {
      md.core.ruler.after("upload-protocol", "resize-controls", rule);
    });
  }
}
