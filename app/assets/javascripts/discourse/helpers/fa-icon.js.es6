import registerUnbound from 'discourse/helpers/register-unbound';

function iconClasses(icon, modifier) {
  var classes = "fa fa-" + icon;
  if (modifier) { classes += " fa-" + modifier; }
  return classes;
}

function iconHTML(icon, label, modifier) {
  var html = "<i class='" + iconClasses(icon, modifier) + "'";
  if (label) { html += " aria-hidden='true'"; }
  html += "></i>";
  if (label) {
    html += "<span class='sr-only'>" + I18n.t(label) + "</span>";
  }
  return html;
}


registerUnbound('fa-icon', function(icon, params) {
  return new Handlebars.SafeString(iconHTML(icon, params.label, params.modifier));
});

export { iconClasses, iconHTML };
