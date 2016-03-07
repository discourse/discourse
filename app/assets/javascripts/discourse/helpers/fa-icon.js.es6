import { h } from 'virtual-dom';
import registerUnbound from 'discourse/helpers/register-unbound';

function iconClasses(icon, params) {
  var classes = "fa fa-" + icon;
  if (params.modifier) { classes += " fa-" + params.modifier; }
  if (params['class']) { classes += ' ' + params['class']; }
  return classes;
}

export function iconHTML(icon, params) {
  params = params || {};

  var html = "<i class='" + iconClasses(icon, params) + "'";
  if (params.label) { html += " aria-hidden='true'"; }
  html += "></i>";
  if (params.label) {
    html += "<span class='sr-only'>" + I18n.t(params.label) + "</span>";
  }
  return html;
}

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


Ember.Handlebars.helper('fa-icon-bound', function(value, options) {
  return new Handlebars.SafeString(iconHTML(value, options));
});

registerUnbound('fa-icon', function(icon, params) {
  return new Handlebars.SafeString(iconHTML(icon, params));
});
