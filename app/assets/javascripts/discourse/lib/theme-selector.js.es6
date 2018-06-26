import { ajax } from "discourse/lib/ajax";
const keySelector = "meta[name=discourse_theme_key]";

export function currentThemeKey() {
  let themeKey = null;
  let elem = _.first($(keySelector));
  if (elem) {
    themeKey = elem.content;
    if (_.isEmpty(themeKey)) {
      themeKey = null;
    }
  }
  return themeKey;
}

export function setLocalTheme(key, themeSeq) {
  if (key) {
    $.cookie("theme_key", `${key},${themeSeq}`, { path: "/", expires: 9999 });
  } else {
    $.cookie("theme_key", null, { path: "/", expires: 1 });
  }
}

export function refreshCSS(node, hash, newHref, options) {
  let $orig = $(node);

  if ($orig.data("reloading")) {
    if (options && options.force) {
      clearTimeout($orig.data("timeout"));
      $orig.data("copy").remove();
    } else {
      return;
    }
  }

  if (!$orig.data("orig")) {
    $orig.data("orig", node.href);
  }

  $orig.data("reloading", true);

  const orig = $(node).data("orig");

  let reloaded = $orig.clone(true);
  if (hash) {
    reloaded[0].href =
      orig + (orig.indexOf("?") >= 0 ? "&hash=" : "?hash=") + hash;
  } else {
    reloaded[0].href = newHref;
  }

  $orig.after(reloaded);

  let timeout = setTimeout(() => {
    $orig.remove();
    reloaded.data("reloading", false);
  }, 2000);

  $orig.data("timeout", timeout);
  $orig.data("copy", reloaded);
}

export function previewTheme(key) {
  if (currentThemeKey() !== key) {
    Discourse.set("assetVersion", "forceRefresh");

    ajax(`/themes/assets/${key ? key : "default"}`).then(results => {
      let elem = _.first($(keySelector));
      if (elem) {
        elem.content = key;
      }

      results.themes.forEach(theme => {
        let node = $(`link[rel=stylesheet][data-target=${theme.target}]`)[0];
        if (node) {
          refreshCSS(node, null, theme.url, { force: true });
        }
      });
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
    results.push({ name: I18n.t("themes.default_description"), id: null });
  }

  themes.forEach(t => {
    results.push({ name: t.name, id: t.theme_key });
  });

  return results.length === 0 ? null : results;
}
