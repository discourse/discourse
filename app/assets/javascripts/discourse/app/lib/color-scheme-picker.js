import { ajax } from "discourse/lib/ajax";
import cookie, { removeCookie } from "discourse/lib/cookie";
import Session from "discourse/models/session";
import discourseLater from "discourse-common/lib/later";
import { i18n } from "discourse-i18n";

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
          name: `${defaultDarkColorScheme.name} ${i18n(
            "user.color_schemes.default_dark_scheme"
          )}`,
        });
      }
    }

    results.unshift({
      id: -1,
      name: i18n("user.color_schemes.disable_dark_scheme"),
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
  return ajax(`/color-scheme-stylesheet/${colorSchemeId}${themeId}.json`).then(
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
          discourseLater(() => {
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

const COLOR_SCHEME_COOKIE_NAME = "color_scheme_id";
const DARK_SCHEME_COOKIE_NAME = "dark_scheme_id";
const COOKIE_EXPIRY_DAYS = 365;

export function updateColorSchemeCookie(id, options = {}) {
  const cookieName = options.dark
    ? DARK_SCHEME_COOKIE_NAME
    : COLOR_SCHEME_COOKIE_NAME;
  if (id) {
    cookie(cookieName, id, {
      path: "/",
      expires: COOKIE_EXPIRY_DAYS,
    });
  } else {
    removeCookie(cookieName, { path: "/" });
  }
}

export function extendColorSchemeCookies() {
  for (const cookieName of [
    COLOR_SCHEME_COOKIE_NAME,
    DARK_SCHEME_COOKIE_NAME,
  ]) {
    const currentValue = cookie(cookieName);
    if (currentValue) {
      cookie(cookieName, currentValue, {
        path: "/",
        expires: COOKIE_EXPIRY_DAYS,
      });
    }
  }
}
