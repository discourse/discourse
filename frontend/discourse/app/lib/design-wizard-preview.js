import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";

const SCHEME_LINK_ID = "design-wizard-preview-scheme";

function hex(colors, name, fallback) {
  const value = colors?.[name] ?? fallback;
  return `#${`${value}`.replace(/[^0-9a-f]/gi, "")}`;
}

/**
 * Builds the inline style for a palette swatch in the design wizard rail.
 *
 * @param {Object} palette - serialized palette with a `colors` map
 * @returns {ReturnType<typeof trustHTML>} inline style string
 */
export function swatchStyle(palette) {
  const bg = hex(palette?.colors, "secondary", "ffffff");
  const accent = hex(palette?.colors, "tertiary", "0088cc");

  return trustHTML(
    `background: linear-gradient(135deg, ${accent} 50%, color-mix(in srgb, ${accent} 18%, ${bg}) 50%)`
  );
}

/**
 * CSS class applying a font's real typeface, defined by the wizard
 * stylesheet target which is always loaded for admins.
 *
 * @param {string} fontKey - font key, e.g. `open_sans`
 * @param {"body" | "heading"} scope
 * @returns {string} class name
 */
export function fontClass(fontKey, scope = "body") {
  return `${scope}-font-${fontKey.replaceAll("_", "-")}`;
}

const fontStacks = new Map();

/**
 * Resolves a font key to its full font-family stack by probing the computed
 * style of the wizard stylesheet's font classes.
 *
 * @param {string} fontKey - font key, e.g. `open_sans`
 * @returns {string} CSS font-family value
 */
export function fontStack(fontKey) {
  if (!fontStacks.has(fontKey)) {
    const probe = document.createElement("span");
    probe.className = fontClass(fontKey);
    probe.hidden = true;
    document.body.appendChild(probe);
    fontStacks.set(fontKey, getComputedStyle(probe).fontFamily);
    probe.remove();
  }

  return fontStacks.get(fontKey);
}

/**
 * Previews a palette in the given document by loading its compiled
 * stylesheet and appending it after every other stylesheet.
 *
 * @param {Document} doc - target document (the app's own, or an iframe's)
 * @param {Object} options
 * @param {number} options.paletteId
 * @param {number} options.themeId
 */
export async function applyPreviewPalette(doc, { paletteId, themeId }) {
  if (!doc?.body || !paletteId) {
    return;
  }

  // built-in palettes that were never materialized have negative ids; the
  // endpoint then falls back to the base light palette, which is the right
  // rendering for the only pair that ships unmaterialized
  const result = await ajax(
    `/color-scheme-stylesheet/${paletteId}/${themeId}.json`
  );
  if (!result?.new_href || !doc.body) {
    return;
  }

  let link = doc.getElementById(SCHEME_LINK_ID);
  if (!link) {
    link = doc.createElement("link");
    link.id = SCHEME_LINK_ID;
    link.rel = "stylesheet";
    link.media = "all";
    doc.body.appendChild(link);
  }
  link.href = result.new_href;
}

/**
 * Previews fonts in the given document by overriding the font custom
 * properties every stylesheet resolves against.
 *
 * @param {Document} doc - target document
 * @param {Object} options
 * @param {string} options.bodyFont - font key
 * @param {string} options.headingFont - font key
 */
export function applyPreviewFonts(doc, { bodyFont, headingFont }) {
  const root = doc?.documentElement;
  if (!root) {
    return;
  }

  root.style.setProperty("--font-family", fontStack(bodyFont));
  root.style.setProperty("--heading-font-family", fontStack(headingFont));
}

/**
 * Previews a default text size in the given document by swapping the
 * text-size class the page was rendered with.
 *
 * @param {Document} doc - target document
 * @param {string} size - text size key, e.g. `larger`
 */
export function applyPreviewTextSize(doc, size) {
  const root = doc?.documentElement;
  if (!root || !size) {
    return;
  }

  const current = [...root.classList].find((klass) =>
    klass.startsWith("text-size-")
  );
  if (root.dataset.designWizardOriginalTextSize === undefined) {
    root.dataset.designWizardOriginalTextSize = current ?? "";
  }
  if (current) {
    root.classList.remove(current);
  }
  root.classList.add(`text-size-${size}`);
}

/**
 * Removes any palette, font and text size previews applied to the given
 * document.
 *
 * @param {Document} doc - target document
 */
export function clearPreview(doc) {
  doc?.getElementById(SCHEME_LINK_ID)?.remove();

  const root = doc?.documentElement;
  if (!root) {
    return;
  }

  root.style.removeProperty("--font-family");
  root.style.removeProperty("--heading-font-family");

  const originalTextSize = root.dataset.designWizardOriginalTextSize;
  if (originalTextSize !== undefined) {
    [...root.classList]
      .filter((klass) => klass.startsWith("text-size-"))
      .forEach((klass) => root.classList.remove(klass));
    if (originalTextSize) {
      root.classList.add(originalTextSize);
    }
    delete root.dataset.designWizardOriginalTextSize;
  }
}
