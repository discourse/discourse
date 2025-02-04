import { i18n } from "discourse-i18n";

const SCALES = ["100", "75", "50"];

let apiExtraButton = [];
let apiExtraButtonAllowList = [];

export function addImageWrapperButton(label, btnClass, icon = null) {
  const markup = [];
  markup.push(`<span class="${btnClass}">`);
  if (icon) {
    markup.push(`
      <svg class="fa d-icon d-icon-${icon} svg-icon svg-string" xmlns="http://www.w3.org/2000/svg">
        <use href="#${icon}"></use>
      </svg>
    `);
  }
  markup.push(label);
  markup.push("</span>");

  apiExtraButton.push(markup.join(""));
  apiExtraButtonAllowList.push(`span.${btnClass}`);
  apiExtraButtonAllowList.push(
    `svg[class=fa d-icon d-icon-${icon} svg-icon svg-string]`
  );
  apiExtraButtonAllowList.push(`use[href=#${icon}]`);
}

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
  return `<span title="
            ${i18n("composer.image_scale_button", { percent: scale })}" 
            class='scale-btn${activeScaleClass}' data-scale='${scale}'
          >
            ${scale}%
          </span>`;
}

function buildImageShowAltTextControls(altText) {
  return `
  <span class="alt-text-readonly-container">
    <span class="alt-text-edit-btn" 
      title="${i18n("composer.image_alt_text.title")}" 
    >
      <svg aria-hidden="true" class="fa d-icon d-icon-pencil svg-icon svg-string"><use href="#pencil"></use></svg>
    </span>
    <span class="alt-text" 
      aria-label="${i18n("composer.image_alt_text.aria_label")}"
    >${altText}</span>
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
        <svg class="fa d-icon d-icon-xmark svg-icon svg-string"><use href="#xmark"></use></svg>
    </button>
  </span>
  `;
}

function buildImageDeleteButton() {
  return `
  <span class="delete-image-button" 
    title="${i18n("composer.delete_image_button")}" 
    aria-label="${i18n("composer.delete_image_button")}"
  >
    <svg class="fa d-icon d-icon-trash-can svg-icon svg-string" xmlns="http://www.w3.org/2000/svg">
      <use href="#trash-can"></use>
    </svg>
  </span>
  `;
}

function buildImageGalleryControl(imageCount) {
  return `
  <span class="wrap-image-grid-button" title="${i18n(
    "composer.toggle_image_grid"
  )}" data-image-count="${imageCount}">
    <svg class="fa d-icon d-icon-table-cells svg-icon svg-string" xmlns="http://www.w3.org/2000/svg">
    <use href="#table-cells"></use>
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
      if (idx === 0) {
        const imageCount = tokens.filter((x) => x.type === "image").length;
        if (imageCount > 1) {
          result += buildImageGalleryControl(imageCount);
        }
      }
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

      result += apiExtraButton.join("");

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
      "use[href=#pencil]",
      "use[href=#trash-can]",

      "span.alt-text-edit-container",
      "span.delete-image-button",
      "span[hidden=true]",
      "input[type=text]",
      "input[class=alt-text-input]",
      "button[class=alt-text-edit-ok btn btn-primary]",
      "svg[class=fa d-icon d-icon-check svg-icon svg-string]",
      "use[href=#check]",
      "button[class=alt-text-edit-cancel btn btn-default]",
      "svg[class=fa d-icon d-icon-xmark svg-icon svg-string]",
      "svg[class=fa d-icon d-icon-trash-can svg-icon svg-string]",
      "use[href=#xmark]",

      "span.wrap-image-grid-button",
      "span.wrap-image-grid-button[data-image-count]",
      "svg[class=fa d-icon d-icon-table-cells svg-icon svg-string]",
      "use[href=#table-cells]",

      ...apiExtraButtonAllowList,
    ]);

    helper.registerPlugin((md) => {
      const oldRule = md.renderer.rules.image;

      md.renderer.rules.image = ruleWithImageControls(oldRule);

      md.core.ruler.after("upload-protocol", "resize-controls", rule);
    });
  }
}
