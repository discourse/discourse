function renderSpinner(cssClass) {
  var html = "<div class='spinner";
  if (cssClass) { html += ' ' + cssClass; }
  return html + "'></div>";
}
var spinnerHTML = renderSpinner();

Ember.Handlebars.registerHelper('loading-spinner', function(params) {
  const hash = params.hash;
  return new Handlebars.SafeString(renderSpinner((hash && hash.size) ? hash.size : undefined));
});

export { spinnerHTML, renderSpinner };
