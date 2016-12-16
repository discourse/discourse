const { registerKeyword } = Ember.__loader.require("ember-htmlbars/keywords");
const { internal } = Ember.__loader.require('htmlbars-runtime');
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

registerKeyword('custom-html', {
  setupState(state, env, scope, params) {
    return { htmlKey: env.hooks.getValue(params[0]) };
  },

  render(renderNode, env, scope, params, hash, template, inverse, visitor) {
    let state = renderNode.getState();
    if (!state.htmlKey) { return true; }

    const html = getCustomHTML(state.htmlKey);
    if (html) {
      const htmlHash = { html };
      env.hooks.component(renderNode,
          env,
          scope,
          'custom-html-container',
          params,
          htmlHash,
          { default: template, inverse },
          visitor);
      return true;
    }

    template = env.owner.lookup(`template:${state.htmlKey}`);
    if (template) {
      internal.hostBlock(renderNode, env, scope, template.raw, null, null, visitor, function(options) {
        options.templates.template.yield();
      });
    }
    return true;
  }
});
