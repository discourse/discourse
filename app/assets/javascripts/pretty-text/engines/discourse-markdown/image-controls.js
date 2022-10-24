import I18n from "I18n";

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
    .find((x) => x.match(/\d{1,4}x\d{1,4}(,\s*\d{1,3}%)?/));
  let selectedScale =
    sizePart && sizePart.split(",").pop().trim().replace("%", "");

  const overwriteScale = !SCALES.find((scale) => scale === selectedScale);
  if (overwriteScale) {
    selectedScale = "100";
  }

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
  }
}

function buildScaleButton(selectedScale, scale) {
  const activeScaleClass = selectedScale === scale ? " active" : "";
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

function buildImageShowAltTextControls(altText) {
  return `
  <span class="alt-text-readonly-container">
  <span class="alt-text-edit-btn">
  <svg aria-hidden="true" class="fa d-icon d-icon-pencil svg-icon svg-string"><use href="#pencil-alt"></use></svg>
</span>

  <span class="alt-text" aria-label="${I18n.t(
    "composer.image_alt_text.aria_label"
  )}">${altText}</span>
  </span>
  `;
}

function buildImageEditAltTextControls(altText) {
  return `
  <span class="alt-text-edit-container" hidden="true">
    <input class="alt-text-input" type="text" value="${altText}" />
    <button class="alt-text-edit-ok btn btn-primary">
        <svg class="fa d-icon d-icon-check svg-icon svg-string"><use href="#check"></use></svg>
    </button>
    <button class="alt-text-edit-cancel btn btn-default">
        <svg class="fa d-icon d-icon-times svg-icon svg-string"><use href="#times"></use></svg>
    </button>
  </span>
  `;
}

function buildImageDeleteButton() {
  return `
  <span class="delete-image-button" aria-label="${I18n.t(
    "composer.delete_image_button"
  )}">
  <svg class="fa d-icon d-icon-trash-alt svg-icon svg-string" xmlns="http://www.w3.org/2000/svg">
  <use href="#far-trash-alt"></use>
  </svg>
   </span>
  `;
}
// We need this to load after `upload-protocol` which is priority 0
export const priority = 1;

function ruleWithImageControls(oldRule) {
  return function (tokens, idx, options, env, slf) {
    const token = tokens[idx];
    const scaleIndex = token.attrIndex("scale");
    const imageIndex = token.attrIndex("index-image");

    if (scaleIndex !== -1) {
      let selectedScale = token.attrs[scaleIndex][1];
      let index = token.attrs[imageIndex][1];

      let result = `<span class="image-wrapper">`;

      result += oldRule(tokens, idx, options, env, slf);

      result += `<span class="button-wrapper" data-image-index="${index}">`;
      result += buildImageShowAltTextControls(
        token.attrs[token.attrIndex("alt")][1]
      );
      result += buildImageEditAltTextControls(
        token.attrs[token.attrIndex("alt")][1]
      );

      result += `<span class="scale-btn-container">`;
      result += SCALES.map((scale) =>
        buildScaleButton(selectedScale, scale)
      ).join("");
      result += `</span>`;
      result += buildImageDeleteButton();

      result += "</span></span>";

      return result;
    } else {
      return oldRule(tokens, idx, options, env, slf);
    }
  };
}

export function setup(helper) {
  const opts = helper.getOptions();
  if (opts.previewing) {
    helper.allowList([
      "span.image-wrapper",
      "span.button-wrapper",
      "span[class=scale-btn-container]",
      "span[class=scale-btn]",
      "span[class=scale-btn active]",
      "span.separator",
      "span.scale-btn[data-scale]",
      "span.button-wrapper[data-image-index]",
      "span[aria-label]",
      "span[class=delete-image-button]",
      "span.alt-text-container",
      "span.alt-text-readonly-container",
      "span.alt-text-readonly-container.alt-text",
      "span.alt-text-readonly-container.alt-text-edit-btn",
      "svg[class=fa d-icon d-icon-pencil svg-icon svg-string]",
      "use[href=#pencil-alt]",
      "use[href=#far-trash-alt]",

      "span.alt-text-edit-container",
      "span.delete-image-button",
      "span[hidden=true]",
      "input[type=text]",
      "input[class=alt-text-input]",
      "button[class=alt-text-edit-ok btn btn-primary]",
      "svg[class=fa d-icon d-icon-check svg-icon svg-string]",
      "use[href=#check]",
      "button[class=alt-text-edit-cancel btn btn-default]",
      "svg[class=fa d-icon d-icon-times svg-icon svg-string]",
      "svg[class=fa d-icon d-icon-trash-alt svg-icon svg-string]",
      "use[href=#times]",
    ]);

    helper.registerPlugin((md) => {
      const oldRule = md.renderer.rules.image;

      md.renderer.rules.image = ruleWithImageControls(oldRule);

      md.core.ruler.after("upload-protocol", "resize-controls", rule);
    });
  }
}
