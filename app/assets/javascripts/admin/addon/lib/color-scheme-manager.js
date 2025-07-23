import { ajax } from "discourse/lib/ajax";

/**
 * determine if a scheme is the built-in default
 * @param {Object} scheme
 * @returns {boolean} true if built-in default scheme
 */
function isBuiltInDefault(scheme) {
  return !scheme || scheme?.is_builtin_default;
}

/**
 * get the scheme ID for API calls
 * @param {Object} scheme
 * @returns {number|null}
 */
function getSchemeId(scheme) {
  return isBuiltInDefault(scheme) ? null : scheme?.id;
}

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

    const id = getSchemeId(scheme);
    const isBuiltIn = isBuiltInDefault(scheme);

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

    const data = await ajax(apiUrl, {
      data: {
        include_dark_scheme: !!darkTag,
      },
      dataType: "json",
    });

    if (data?.new_href && lightTag) {
      lightTag.href = data.new_href;

      if (replace && id) {
        lightTag.setAttribute("data-scheme-id", id);
      } else if (replace && isBuiltIn) {
        lightTag.removeAttribute("data-scheme-id");
      }
    }

    if (data?.new_dark_href && darkTag) {
      darkTag.href = data.new_dark_href;

      if (replace && id) {
        darkTag.setAttribute("data-scheme-id", id);
      } else if (replace && isBuiltIn) {
        darkTag.removeAttribute("data-scheme-id");
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
 * @param {Object} options
 * @param {boolean} options.reload - reload the page after setting? (default: false)
 * @returns {Promise}
 */

export async function setDefaultColorScheme(scheme, store, options = {}) {
  const { reload = false } = options;

  try {
    // can't live preview if isBuiltInDefault
    const isBuiltIn = isBuiltInDefault(scheme);
    const shouldReload = reload || isBuiltIn;

    if (!shouldReload) {
      await applyColorScheme(scheme, { replace: true });
    }

    const themes = await store.findAll("theme");
    const defaultTheme = themes.findBy("default", true);

    if (!defaultTheme) {
      throw new Error("Could not find default theme");
    }

    const schemeId = getSchemeId(scheme);
    defaultTheme.set("color_scheme_id", schemeId);

    await defaultTheme.saveChanges("color_scheme_id");

    if (shouldReload) {
      window.location.reload();
    }

    return defaultTheme;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("Failed to set default color scheme", error);
    throw error;
  }
}
