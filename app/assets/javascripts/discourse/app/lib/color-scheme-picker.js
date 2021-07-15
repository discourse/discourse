import cookie, { removeCookie } from "discourse/lib/cookie";
import I18n from "I18n";
import Session from "discourse/models/session";
import { ajax } from "discourse/lib/ajax";
import { later } from "@ember/runloop";

export function listColorSchemes(site, options = {}) {
  let schemes = site.get("user_color_schemes");

  if (!schemes || !Array.isArray(schemes)) {
    return null;
  }

  let results = [];

  if (!options.darkOnly) {
    schemes = schemes.sort((a, b) => Number(a.is_dark) - Number(b.is_dark));
  }
  schemes.forEach((s) => {
    if ((options.darkOnly && s.is_dark) || !options.darkOnly) {
      results.push({
        name: s.name,
        id: s.id,
      });
    }
  });

  if (options.darkOnly) {
    const defaultDarkColorScheme = site.get("default_dark_color_scheme");
    if (defaultDarkColorScheme) {
      const existing = schemes.findBy("id", defaultDarkColorScheme.id);
      if (!existing) {
        results.unshift({
          id: defaultDarkColorScheme.id,
          name: `${defaultDarkColorScheme.name} ${I18n.t(
            "user.color_schemes.default_dark_scheme"
          )}`,
        });
      }
    }

    results.unshift({
      id: -1,
      name: I18n.t("user.color_schemes.disable_dark_scheme"),
    });
  }

  return results.length === 0 ? null : results;
}

export function loadColorSchemeStylesheet(
  colorSchemeId,
  theme_id,
  darkMode = false
) {
  const themeId = theme_id ? `/${theme_id}` : "";
  ajax(`/color-scheme-stylesheet/${colorSchemeId}${themeId}.json`).then(
    (result) => {
      if (result && result.new_href) {
        const elementId = darkMode ? "cs-preview-dark" : "cs-preview-light";
        const existingElement = document.querySelector(`link#${elementId}`);
        if (existingElement) {
          existingElement.href = result.new_href;
        } else {
          let link = document.createElement("link");
          link.href = result.new_href;
          link.media = darkMode
            ? "(prefers-color-scheme: dark)"
            : "(prefers-color-scheme: light)";
          link.rel = "stylesheet";
          link.id = elementId;

          document.body.appendChild(link);
        }
        if (!darkMode) {
          later(() => {
            const schemeType = getComputedStyle(document.body).getPropertyValue(
              "--scheme-type"
            );

            Session.currentProp(
              "defaultColorSchemeIsDark",
              schemeType.trim() === "dark"
            );
          }, 500);
        }
      }
    }
  );
}

export function updateColorSchemeCookie(id, options = {}) {
  const cookieName = options.dark ? "dark_scheme_id" : "color_scheme_id";
  if (id) {
    cookie(cookieName, id, {
      path: "/",
      expires: 9999,
    });
  } else {
    removeCookie(cookieName, { path: "/", expires: 1 });
  }
}
