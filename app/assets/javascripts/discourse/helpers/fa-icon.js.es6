Handlebars.registerHelper('fa-icon', function(icon, options) {
  var labelKey;
  if (options.hash) { labelKey = options.hash.label; }

  var html = "<i class='fa fa-" + icon + "'";
  if (labelKey) { html += " aria-hidden='true'"; }
  html += "></i>";
  if (labelKey) {
    html += "<span class='sr-only'>" + I18n.t(labelKey) + "</span>";
  }
  return new Handlebars.SafeString(html);
});
