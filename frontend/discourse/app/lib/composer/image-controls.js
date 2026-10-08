import { iconElement } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

const SCALES = ["100", "75", "50"];

const extraButtons = [];

export function addImageWrapperButton(
  label,
  btnClass,
  icon = null,
  includeCondition = null
) {
  extraButtons.push({ label, btnClass, icon, condition: includeCondition });
}

function element(tag, attributes, ...children) {
  const el = document.createElement(tag);

  for (const [name, value] of Object.entries(attributes)) {
    el.setAttribute(name, value);
  }

  el.append(...children.filter(Boolean));
  return el;
}

function buildScaleButton(selectedScale, scale) {
  return element(
    "span",
    {
      class: selectedScale === scale ? "scale-btn active" : "scale-btn",
      title: i18n("composer.image_scale_button", { percent: scale }),
      "data-scale": scale,
    },
    `${scale}%`
  );
}

function buildShowAltTextControls(altText) {
  return element(
    "span",
    { class: "alt-text-readonly-container" },
    element(
      "span",
      {
        class: "alt-text-edit-btn",
        title: i18n("composer.image_alt_text.title"),
      },
      iconElement("pencil")
    ),
    element(
      "span",
      {
        class: "alt-text",
        "aria-label": i18n("composer.image_alt_text.aria_label"),
      },
      altText
    )
  );
}

function buildEditAltTextControls(altText) {
  const input = element("input", {
    class: "alt-text-input",
    type: "text",
  });
  input.value = altText;

  return element(
    "span",
    { class: "alt-text-edit-container", hidden: "true" },
    input,
    element(
      "button",
      { class: "alt-text-edit-ok btn btn-primary" },
      iconElement("check")
    ),
    element(
      "button",
      { class: "alt-text-edit-cancel btn btn-default" },
      iconElement("xmark")
    )
  );
}

function buildDeleteButton() {
  return element(
    "span",
    {
      class: "delete-image-button",
      title: i18n("composer.delete_image_button"),
      "aria-label": i18n("composer.delete_image_button"),
    },
    iconElement("trash-can")
  );
}

function buildGalleryButton(imageCount) {
  return element(
    "span",
    {
      class: "wrap-image-grid-button",
      title: i18n("composer.toggle_image_grid"),
      "data-image-count": imageCount,
    },
    iconElement("table-cells")
  );
}

function buildExtraButton({ label, btnClass, icon }) {
  return element(
    "span",
    { class: btnClass },
    icon ? iconElement(icon) : null,
    label
  );
}

function buildButtonWrapper(image) {
  const altText = image.getAttribute("alt") || "";
  const imageCount = parseInt(image.dataset.imageRun, 10);

  const wrapper = element("span", {
    class: "button-wrapper",
    "data-image-index": image.dataset.imageIndex,
  });

  if (imageCount > 1) {
    wrapper.append(buildGalleryButton(imageCount));
  }

  wrapper.append(
    buildShowAltTextControls(altText),
    buildEditAltTextControls(altText),
    element(
      "span",
      { class: "scale-btn-container" },
      ...SCALES.map((scale) => buildScaleButton(image.dataset.scale, scale))
    ),
    buildDeleteButton()
  );

  const uploadUrl = image.getAttribute("data-orig-src");
  for (const button of extraButtons) {
    if (!button.condition || button.condition(uploadUrl)) {
      wrapper.append(buildExtraButton(button));
    }
  }

  return wrapper;
}

export function decorateImageControls(preview) {
  preview
    .querySelectorAll("img[data-image-index][data-scale]")
    .forEach((image) => {
      const wrapper = element("span", { class: "image-wrapper" });

      image.replaceWith(wrapper);
      wrapper.append(image, buildButtonWrapper(image));
    });
}
