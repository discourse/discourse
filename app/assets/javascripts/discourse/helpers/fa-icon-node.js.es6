import { h } from 'virtual-dom';
import { iconClasses } from 'discourse-common/helpers/fa-icon';

export function iconNode(icon, params) {
  params = params ||  {};

  const properties = {
    className: iconClasses(icon, params),
    attributes: { "aria-hidden": true }
  };

  if (params.title) { properties.attributes.title = params.title; }

  if (params.label) {
    return h('i', properties, h('span.sr-only', I18n.t(params.label)));
  } else {
    return h('i', properties);
  }
}

