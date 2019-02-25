import { ajax } from "discourse/lib/ajax";
import deprecated from "discourse-common/lib/deprecated";

const keySelector = "meta[name=discourse_theme_ids]";

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
  const elem = _.first($(keySelector));
  if (elem) {
    elem.content.split(",").forEach(num => {
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
  ids = ids.reject(id => !id);
  if (ids && ids.length > 0) {
    $.cookie("theme_ids", `${ids.join(",")}|${themeSeq}`, {
      path: "/",
      expires: 9999
    });
  } else {
    $.removeCookie("theme_ids", { path: "/", expires: 1 });
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

export function previewTheme(ids = []) {
  ids = ids.reject(id => !id);
  if (!ids.includes(currentThemeId())) {
    Discourse.set("assetVersion", "forceRefresh");

    ajax(`/themes/assets/${ids.length > 0 ? ids.join("-") : "default"}`).then(
      results => {
        const elem = _.first($(keySelector));
        if (elem) {
          elem.content = ids.join(",");
        }

        results.themes.forEach(theme => {
          const node = $(
            `link[rel=stylesheet][data-target=${theme.target}]`
          )[0];
          if (node) {
            refreshCSS(node, null, theme.new_href, { force: true });
          }
        });
      }
    );
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
    results.push({ name: t.name, id: t.theme_id });
  });

  return results.length === 0 ? null : results;
}
