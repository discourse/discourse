import { trustHTML } from "@ember/template";

function hex(colors, name, fallback) {
  const value = colors?.[name] ?? fallback;
  return `#${`${value}`.replace(/[^0-9a-f]/gi, "")}`;
}

// base light values, for a palette serialized without one of the colors
const PALETTE_CARD_COLORS = {
  secondary: "ffffff",
  primary: "222222",
  tertiary: "0088cc",
  quaternary: "e45735",
  love: "fa6c8d",
  highlight: "ffff4d",
};

/**
 * Builds the custom properties a design wizard palette card draws its
 * preview from.
 *
 * @param {{ colors?: Record<string, string> } | null | undefined} palette - serialized palette with a resolved `colors` map
 * @param {import("discourse/lib/design-wizard-sidebar-colors").SidebarColors} [sidebar] - the theme's sidebar colors under this palette, already validated as colors
 * @returns {import("@ember/template").TrustedHTML} inline style string
 */
export function paletteCardStyle(palette, sidebar) {
  const colors = Object.fromEntries(
    Object.entries(PALETTE_CARD_COLORS).map(([name, fallback]) => [
      name,
      hex(palette?.colors, name, fallback),
    ])
  );

  // until the theme's colors resolve, the strip blends into the content
  const properties = {
    ...colors,
    "sidebar-background": sidebar?.background ?? colors.secondary,
    "sidebar-active": sidebar?.active ?? colors.tertiary,
    "sidebar-link": sidebar?.link ?? colors.primary,
    "sidebar-border": sidebar?.border ?? "transparent",
  };

  return trustHTML(
    Object.entries(properties)
      .map(([name, value]) => `--palette-${name}: ${value}`)
      .join("; ")
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
