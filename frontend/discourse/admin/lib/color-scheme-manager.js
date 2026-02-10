import ColorScheme from "discourse/admin/models/color-scheme";
import { ajax } from "discourse/lib/ajax";

/**
 * apply color scheme by updating stylesheet links
 *
 * @param {Object} scheme - color scheme to apply
 * @param {Object} options
 * @param {boolean} options.replace - replace existing tags? (default: false)
 * @param {boolean} options.save - save changes to the server? (default: false)
 * @returns {Promise}
 */

export async function applyColorScheme(scheme, options = {}) {
  const { replace = false, save = false } = options;

  try {
    if (save && scheme && scheme.save) {
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
            darkTag = darkTag || link;
          } else {
            lightTag = lightTag || link;
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

    const apiUrl = `/color-scheme-stylesheet/${id}.json`;

    const data = await ajax(apiUrl);

    if (data?.new_href && lightTag) {
      lightTag.href = data.new_href;

      if (replace && id) {
        lightTag.setAttribute("data-scheme-id", id);
      } else if (replace && !id) {
        lightTag.removeAttribute("data-scheme-id");
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
 * set color scheme as active for the default theme and apply immediately
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
      await applyColorScheme(scheme, { replace: true });
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

      if (currentSchemeId && currentSchemeId > 0) {
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
