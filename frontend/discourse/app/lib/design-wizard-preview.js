import { trustHTML } from "@ember/template";

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
