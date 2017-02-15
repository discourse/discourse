import { registerUnbound } from 'discourse-common/lib/helpers';

export function iconClasses(icon, params) {
  let classes = "fa fa-" + icon;
  if (params.modifier) { classes += " fa-" + params.modifier; }
  if (params['class']) { classes += ' ' + params['class']; }
  return classes;
}

export function iconHTML(icon, params) {
  params = params || {};

  var html = "<i class='" + iconClasses(icon, params) + "'";
  if (params.title) { html += ` title='${I18n.t(params.title)}'`; }
  if (params.label) { html += " aria-hidden='true'"; }
  html += "></i>";
  if (params.label) {
    html += "<span class='sr-only'>" + I18n.t(params.label) + "</span>";
  }
  return html;
}

registerUnbound('fa-icon', function(icon, params) {
  return new Handlebars.SafeString(iconHTML(icon, params));
});
