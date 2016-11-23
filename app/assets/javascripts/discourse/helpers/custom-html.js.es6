import { registerHelper } from 'discourse-common/lib/helpers';
import PreloadStore from 'preload-store';

let _customizations = {};

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

export function clearHTMLCache() {
  _customizations = {};
}

// Set a fragment of HTML by key. It can then be looked up with `getCustomHTML(key)`.
export function setCustomHTML(key, html) {
  _customizations[key] = html;
}

registerHelper('custom-html', function([id, contextString], hash, options, env) {
  const html = getCustomHTML(id);
  if (html) { return html; }

  if (env) {
    const target = (env || contextString);
    const container = target.container || target.data.view.container;
    if (container.lookup('template:' + id)) {
      return env.helpers.partial.helperFunction.apply(this, arguments);
    }
  }
});
