import cookie, { removeCookie } from "discourse/lib/cookie";
import I18n from "I18n";
import deprecated from "discourse-common/lib/deprecated";

const keySelector = "meta[name=discourse_theme_id]";

export function currentThemeKey() {
  // eslint-disable-next-line no-console
  if (console && console.warn && console.trace) {
    // TODO: Remove this code Jan 2019
    deprecated(
      "'currentThemeKey' is is deprecated use 'currentThemeId' instead. A theme component may require updating."
    );
  }
}

export function currentThemeIds() {
  const themeIds = [];
  const elem = $(keySelector)[0];
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
    cookie("theme_ids", `${ids.join(",")}|${themeSeq}`, {
      path: "/",
      expires: 9999,
    });
  } else {
    removeCookie("theme_ids", { path: "/", expires: 1 });
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
    results.push({ name: I18n.t("themes.default_description"), id: null });
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
