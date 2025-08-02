import cookie, { removeCookie } from "discourse/lib/cookie";
import deprecated from "discourse/lib/deprecated";
import { i18n } from "discourse-i18n";

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
  ids = ids.reject((id) => !id);
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

export function listThemes(site) {
  let themes = site.get("user_themes");

  if (!themes) {
    return null;
  }

  let hasDefault = !!themes.findBy("default", true);

  let results = [];
  if (!hasDefault) {
    results.push({ name: i18n("themes.default_description"), id: null });
  }

  themes.forEach((t) => {
    results.push({
      name: t.name,
      id: t.theme_id,
      color_scheme_id: t.color_scheme_id,
    });
  });

  return results.length === 0 ? null : results;
}
