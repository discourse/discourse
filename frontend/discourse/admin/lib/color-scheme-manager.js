import ColorScheme from "discourse/admin/models/color-scheme";
import { ajax } from "discourse/lib/ajax";

const MODES = ["light", "dark"];

function schemeLink(mode) {
  return document.querySelector(`link.${mode}-scheme`);
}

/**
 * @typedef {Object} ColorSchemeLinkState
 * @property {?{href: ?string, media: ?string}} light
 * @property {?{href: ?string, media: ?string}} dark
 */

/**
 * Snapshots the light/dark stylesheet links so a preview can be undone.
 *
 * @returns {ColorSchemeLinkState}
 */
export function captureColorSchemeLinks() {
  return Object.fromEntries(
    MODES.map((mode) => {
      const link = schemeLink(mode);

      return [
        mode,
        link
          ? {
              href: link.getAttribute("href"),
              media: link.getAttribute("media"),
            }
          : null,
      ];
    })
  );
}

/**
 * Restores links snapshotted by {@link captureColorSchemeLinks}.
 *
 * @param {?ColorSchemeLinkState} original
 */
export function restoreColorSchemeLinks(original) {
  if (!original) {
    return;
  }

  for (const mode of MODES) {
    const link = schemeLink(mode);
    const originalLink = original[mode];

    if (!link || !originalLink) {
      continue;
    }

    for (const attribute of ["href", "media"]) {
      if (originalLink[attribute] === null) {
        link.removeAttribute(attribute);
      } else {
        link.setAttribute(attribute, originalLink[attribute]);
      }
    }

    link.removeAttribute("data-scheme-id");
  }
}

/**
 * Which color mode the page is currently rendering.
 *
 * @returns {"light" | "dark"}
 */
export function renderedColorMode() {
  const isActive = (link) =>
    link &&
    link.media !== "none" &&
    window.matchMedia(link.media || "all").matches;

  const lightIsActive = isActive(schemeLink("light"));
  const darkIsActive = isActive(schemeLink("dark"));

  return darkIsActive && !lightIsActive ? "dark" : "light";
}

/**
 * Forces the page to render one color mode.
 *
 * @param {"light" | "dark"} mode
 */
export function showColorMode(mode) {
  const lightTag = schemeLink("light");
  const darkTag = schemeLink("dark");

  if (lightTag && darkTag) {
    lightTag.media = mode === "light" ? "all" : "none";
    darkTag.media = mode === "dark" ? "all" : "none";
  } else {
    (lightTag ?? darkTag)?.setAttribute("media", "all");
  }
}

/**
 * Apply color scheme by updating stylesheet links
 *
 * @param {Object} scheme - color scheme to apply
 * @param {Object} options
 * @param {boolean} options.replace - replace existing tags? (default: false)
 * @param {boolean} options.save - save changes to the server? (default: false)
 * @param {number} options.themeId - compile against this theme's color
 *   definitions instead of the default theme's (default: none)
 * @param {"light" | "dark"} options.mode - stylesheet to replace
 * @returns {Promise}
 */

export async function applyColorScheme(scheme, options = {}) {
  const {
    replace = false,
    save = false,
    themeId = null,
    mode = "light",
  } = options;

  try {
    if (save && scheme?.save) {
      await scheme.save({ forceSave: true });
    }

    const id = scheme?.id;

    let existingTags = [];
    if (id) {
      existingTags = document.querySelectorAll(`link[data-scheme-id="${id}"]`);
    }

    if (existingTags.length === 0 && !replace) {
      return;
    }

    let darkTag;
    let lightTag;

    if (replace) {
      const colorSchemeStylesheets = document.querySelectorAll(
        "link[rel='stylesheet']"
      );

      for (const link of colorSchemeStylesheets) {
        if (
          link.hasAttribute("data-scheme-id") ||
          link.classList.contains("dark-scheme") ||
          link.classList.contains("light-scheme") ||
          link.href.includes("color-scheme-stylesheet")
        ) {
          if (
            link.href.includes("dark_scheme") ||
            link.classList.contains("dark-scheme")
          ) {
            darkTag ||= link;
          } else {
            lightTag ||= link;
          }
        }
      }
    } else {
      for (const tag of existingTags) {
        if (tag.classList.contains("dark-scheme")) {
          darkTag = tag;
        } else {
          lightTag = tag;
        }
      }
    }

    if (!id) {
      return;
    }

    const themeSegment = themeId === null ? "" : `/${themeId}`;
    const data = await ajax(
      `/color-scheme-stylesheet/${id}${themeSegment}.json`
    );

    const targetTag =
      mode === "dark" ? (darkTag ?? lightTag) : (lightTag ?? darkTag);

    if (data?.new_href && targetTag) {
      targetTag.href = data.new_href;

      if (replace) {
        targetTag.setAttribute("data-scheme-id", id);
      }
    }

    return data;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(`Failed to apply changes to color scheme`, error);
    throw error;
  }
}

/**
 * Set color scheme as active for the default theme and apply immediately
 *
 * @param {Object} scheme - color scheme to set as default
 * @param {Object} defaultTheme - the default theme object
 * @param {Object} options
 * @param {string} options.previewMode - preview mode: "live", "none", or "reload" (default: auto-detect)
 * @param {string} options.mode - "light" or "dark" (default: "light")
 * @returns {Promise}
 */

export async function setDefaultColorScheme(
  scheme,
  defaultTheme,
  options = {}
) {
  const { previewMode = "live", mode = "light" } = options;

  try {
    if (previewMode === "live") {
      await applyColorScheme(scheme, { replace: true, mode });
    }

    if (!defaultTheme) {
      throw new Error("Could not find default theme");
    }

    const themeField =
      mode === "light" ? "color_scheme_id" : "dark_color_scheme_id";
    const schemeField =
      mode === "light" ? "default_light_on_theme" : "default_dark_on_theme";

    if (!scheme.is_base) {
      await scheme.updateDefaultOnTheme(schemeField, true);
      defaultTheme[themeField] = scheme.id;
    } else {
      const currentSchemeId = defaultTheme[themeField];

      if (currentSchemeId > 0) {
        const currentScheme = ColorScheme.create({ id: currentSchemeId });
        await currentScheme.updateDefaultOnTheme(schemeField, false);
      }

      defaultTheme[themeField] = null;
    }

    if (previewMode === "reload") {
      window.location.reload();
    }

    return defaultTheme;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("Failed to set default color scheme", error);
    throw error;
  }
}
