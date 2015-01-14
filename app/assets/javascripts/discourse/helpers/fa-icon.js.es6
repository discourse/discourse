export function iconHTML(icon, label) {
  var html = "<i class='fa fa-" + icon + "'";
  if (label) { html += " aria-hidden='true'"; }
  html += "></i>";
  if (label) {
    html += "<span class='sr-only'>" + I18n.t(label) + "</span>";
  }
  return html;
}

Handlebars.registerHelper('fa-icon', function(icon, options) {
  var label;
  if (options.hash) { label = options.hash.label; }

  return new Handlebars.SafeString(iconHTML(icon, label));
});
