import { modifier } from "ember-modifier";

/** The custom property a chip row reads to keep a long placeholder whole. */
const WIDTH_PROPERTY = "--d-select-placeholder-width";

let canvas: HTMLCanvasElement | undefined;

/** The width of a text in an element's own font, so wide scripts such as CJK measure right. */
function textWidth(element: HTMLElement, text: string): number {
  canvas ??= document.createElement("canvas");
  const context = canvas.getContext("2d");
  if (!context) {
    return 0;
  }
  const style = getComputedStyle(element);
  context.font =
    style.font ||
    `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
  return Math.ceil(context.measureText(text).width);
}

/**
 * Publishes the placeholder's rendered width on the input. A native placeholder never wraps, so a
 * chip row uses the width to move the input to its own row only when the text doesn't fit beside
 * the chips. Measured again once web fonts load, since a fallback font measures differently.
 */
const measurePlaceholder = modifier(
  (element: HTMLInputElement, [placeholder]: [string | undefined]) => {
    let live = true;
    const measure = () => {
      if (!live) {
        return;
      }
      if (placeholder) {
        element.style.setProperty(
          WIDTH_PROPERTY,
          `${textWidth(element, placeholder)}px`
        );
      } else {
        element.style.removeProperty(WIDTH_PROPERTY);
      }
    };
    measure();
    void document.fonts?.ready.then(measure);
    return () => {
      live = false;
    };
  }
);

export default measurePlaceholder;
