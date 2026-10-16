import cookie, { removeCookie } from "discourse/lib/cookie";
import deprecated from "discourse/lib/deprecated";
import { i18n } from "discourse-i18n";

// Matches CORE_THEMES in app/models/theme.rb
export const FOUNDATION_THEME_ID = -1;
export const HORIZON_THEME_ID = -2;

const keySelector = "meta[name=discourse_theme_id]";
const COOKIE_NAME = "theme_ids";
const COOKIE_EXPIRY_DAYS = 365;

export function currentThemeKey() {
  // eslint-disable-next-line no-console
  if (console && console.warn && console.trace) {
    // TODO: Remove this code Jan 2019
    deprecated(
      "'currentThemeKey' is deprecated use 'currentThemeId' instead. A theme component may require updating.",
      { id: "discourse.current-theme-key" }
    );
  }
}

export function currentThemeIds() {
  const themeIds = [];
  const elem = document.querySelector(keySelector);
  if (elem) {
    elem.content.split(",").forEach((num) => {
      num = parseInt(num, 10);
      if (!isNaN(num)) {
        themeIds.push(num);
      }
    });
  }
  return themeIds;
}

export function currentThemeId() {
  return currentThemeIds()[0];
}

export function setLocalTheme(ids, themeSeq) {
  ids = ids.filter(Boolean);
  if (ids && ids.length > 0) {
    cookie(COOKIE_NAME, `${ids.join(",")}|${themeSeq}`, {
      path: "/",
      expires: COOKIE_EXPIRY_DAYS,
    });
  } else {
    removeCookie(COOKIE_NAME, { path: "/" });
  }
}

export function extendThemeCookie() {
  const currentValue = cookie(COOKIE_NAME);
  if (currentValue) {
    cookie(COOKIE_NAME, currentValue, {
      path: "/",
      expires: COOKIE_EXPIRY_DAYS,
    });
  }
}

/**
 * A theme the current user can choose. The site default has a `null` id when
 * no theme is marked as the default.
 *
 * @typedef {object} SelectableTheme
 * @property {string} name
 * @property {number | null} id
 * @property {number | null} [color_scheme_id]
 * @property {number | null} [dark_color_scheme_id]
 * @property {boolean} [only_theme_color_schemes]
 */

/**
 * @param {import("discourse/models/site").default} site
 * @returns {SelectableTheme[] | null}
 */
export function listThemes(site) {
  let themes = site.get("user_themes");

  if (!themes) {
    return null;
  }

  let hasDefault = !!themes.find((theme) => theme.default);

  let results = [];
  if (!hasDefault) {
    results.push({ name: i18n("themes.default_description"), id: null });
  }

  themes.forEach((t) => {
    results.push({
      name: t.name,
      id: t.theme_id,
      color_scheme_id: t.color_scheme_id,
      dark_color_scheme_id: t.dark_color_scheme_id,
      only_theme_color_schemes: t.only_theme_color_schemes,
    });
  });

  return results.length === 0 ? null : results;
}
