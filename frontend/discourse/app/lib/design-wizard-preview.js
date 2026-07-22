import { trustHTML } from "@ember/template";
import { HORIZON_THEME_ID } from "discourse/lib/theme-selector";

function hex(colors, name, fallback) {
  const value = colors?.[name] ?? fallback;
  return `#${`${value}`.replace(/[^0-9a-f]/gi, "")}`;
}

/**
 * Builds the inline style powering the design wizard's mock site preview.
 * All preview elements are colored exclusively through these custom
 * properties, computed from a palette's real color values.
 *
 * @param {Object} options
 * @param {Object} options.colors - color name to hex map (without `#`)
 * @param {number} options.themeId - selected theme id
 * @returns {ReturnType<typeof htmlSafe>} inline style string
 */
export function previewStyle({ colors, themeId }) {
  const bg = hex(colors, "secondary", "ffffff");
  const fg = hex(colors, "primary", "222222");
  const accent = hex(colors, "tertiary", "0088cc");

  const vars = {
    "--dw-bg": bg,
    "--dw-fg": fg,
    "--dw-accent": accent,
    "--dw-header-bg": hex(colors, "header_background", "ffffff"),
    "--dw-header-fg": hex(colors, "header_primary", "333333"),
    "--dw-muted": `color-mix(in srgb, ${fg} 55%, ${bg})`,
    "--dw-border": `color-mix(in srgb, ${fg} 14%, ${bg})`,
    "--dw-soft": `color-mix(in srgb, ${accent} 15%, ${bg})`,
    "--dw-accent-fg": `color-mix(in srgb, ${accent} 70%, ${fg})`,
    "--dw-radius": themeId === HORIZON_THEME_ID ? "12px" : "4px",
  };

  return trustHTML(
    Object.entries(vars)
      .map(([property, value]) => `${property}: ${value}`)
      .join("; ")
  );
}

/**
 * Builds the inline style for a palette swatch in the design wizard rail.
 *
 * @param {Object} palette - serialized palette with a `colors` map
 * @returns {ReturnType<typeof htmlSafe>} inline style string
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
