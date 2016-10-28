import { registerHelper } from 'discourse-common/lib/helpers';
import PreloadStore from 'preload-store';

const _customizations = {};

export function getCustomHTML(key) {
  const c = _customizations[key];
  if (c) {
    return new Handlebars.SafeString(c);
  }

  const html = PreloadStore.get("customHTML");
  if (html && html[key] && html[key].length) {
    return new Handlebars.SafeString(html[key]);
  }
}

// Set a fragment of HTML by key. It can then be looked up with `getCustomHTML(key)`.
export function setCustomHTML(key, html) {
  _customizations[key] = html;
}

registerHelper('custom-html', function([id]) {
  const html = getCustomHTML(id);
  if (html) { return html; }
});
