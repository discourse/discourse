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

function probeFontStack(fontKey) {
  const probe = document.createElement("span");
  probe.className = fontClass(fontKey);
  probe.hidden = true;
  document.body.appendChild(probe);

  try {
    const probed = getComputedStyle(probe).fontFamily;
    // the stylesheet defining the font classes may not have loaded yet
    const inherited = getComputedStyle(document.body).fontFamily;
    return probed === inherited ? null : probed;
  } finally {
    probe.remove();
  }
}

/**
 * Resolves a font key to its full font-family stack by probing the computed
 * style of the wizard stylesheet's font classes.
 *
 * Memoized only once the defining stylesheet has loaded, so an early probe
 * can't pin a wrong stack for the page's lifetime.
 *
 * @param {string} fontKey - font key, e.g. `open_sans`
 * @returns {?string} CSS font-family value, or null if not yet resolvable
 */
export function fontStack(fontKey) {
  if (!fontStacks.has(fontKey)) {
    const probed = probeFontStack(fontKey);
    if (probed === null) {
      return null;
    }

    fontStacks.set(fontKey, probed);
  }

  return fontStacks.get(fontKey);
}

/**
 * Previews fonts in the given document by overriding the font custom
 * properties every stylesheet resolves against.
 *
 * Only the family is overridden, not the per-font letter spacing and feature
 * settings the stylesheet importer emits, so fonts defining those preview
 * slightly differently than they save.
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

  const families = {
    "--font-family": fontStack(bodyFont),
    "--heading-font-family": fontStack(headingFont),
  };

  for (const [property, family] of Object.entries(families)) {
    if (family) {
      root.style.setProperty(property, family);
    } else {
      // leave the saved font in place rather than fall back to the browser's
      root.style.removeProperty(property);
    }
  }
}

/**
 * Removes font previews applied to the given document.
 *
 * @param {Document} doc - target document
 */
export function clearPreview(doc) {
  const root = doc?.documentElement;
  if (!root) {
    return;
  }

  root.style.removeProperty("--font-family");
  root.style.removeProperty("--heading-font-family");
}
