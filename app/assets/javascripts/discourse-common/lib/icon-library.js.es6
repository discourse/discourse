import { h } from 'virtual-dom';
let _renderers = [];

export function renderIcon(renderType, id, params) {
  for (let i=0; i<_renderers.length; i++) {
    let renderer = _renderers[i];
    let rendererForType = renderer[renderType];

    if (rendererForType) {
      let result = rendererForType(id, params || {});
      if (result) {
        return result;
      }
    }
  }
}

export function iconHTML(id, params) {
  return renderIcon('string', id, params);
}

export function iconNode(id, params) {
  return renderIcon('node', id, params);
}

Discourse.__widget_helpers.iconNode = iconNode;

export function registerIconRenderer(renderer) {
  _renderers.unshift(renderer);
}

// Support for font awesome icons
function faClasses(id, params) {
  let classNames = `fa fa-${id} d-icon d-icon-${id}`;
  if (params) {
    if (params.modifier) { classNames += " fa-" + params.modifier; }
    if (params['class']) { classNames += ' ' + params['class']; }
  }
  return classNames;
}

// default resolver is font awesome
registerIconRenderer({
  name: 'font-awesome',

  string(id, params) {
    let tagName = params.tagName || 'i';
    let html = `<${tagName} class='${faClasses(id, params)}'`;
    if (params.title) { html += ` title='${I18n.t(params.title)}'`; }
    if (params.label) { html += " aria-hidden='true'"; }
    html += `></${tagName}>`;
    if (params.label) {
      html += "<span class='sr-only'>" + I18n.t(params.label) + "</span>";
    }
    return html;
  },

  node(id, params) {
    let tagName = params.tagName || 'i';

    const properties = {
      className: faClasses(id, params),
      attributes: { "aria-hidden": true }
    };

    if (params.title) { properties.attributes.title = params.title; }
    if (params.label) {
      return h(tagName, properties, h('span.sr-only', I18n.t(params.label)));
    } else {
      return h(tagName, properties);
    }
  }
});
