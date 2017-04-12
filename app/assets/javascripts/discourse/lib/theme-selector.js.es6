import { ajax } from 'discourse/lib/ajax';
import { refreshCSS } from 'discourse/initializers/live-development';
const keySelector = 'meta[name=discourse_theme_key]';

export function currentThemeKey() {
  let themeKey = null;
  let elem = _.first($(keySelector));
  if (elem) {
    themeKey = elem.content;
  }
  return themeKey;
}

export function selectDefaultTheme(key) {
  if (key) {
    $.cookie('preview_style', key, {path: '/', expires: 9999});
  } else {
    $.cookie('preview_style', null, {path: '/', expires: 1});
  }
}

export function previewTheme(key) {
  if (currentThemeKey() !== key) {

    Discourse.set("assetVersion", "forceRefresh");

    ajax(`/themes/assets/${key ? key : 'default'}`).then(results => {
      let elem = _.first($(keySelector));
      if (elem) {
        elem.content = key;
      }

      results.themes.forEach(theme => {
        let node = $(`link[rel=stylesheet][data-target=${theme.target}]`)[0];
        if (node) {
          refreshCSS(node, null, theme.url, {force: true});
        }
      });
    });
  }
}

export function listThemes(site) {
  let themes = site.get('user_themes');

  if (!themes) {
    return null;
  }

  let hasDefault = !!themes.findBy('default', true);

  let results = [];
  if (!hasDefault) {
    results.push({name: I18n.t('themes.default_description'), id: null});
  }

  themes.forEach(t=>{
    results.push({name: t.name, id: t.theme_key});
  });

  return results.length === 0 ? null : results;
}
