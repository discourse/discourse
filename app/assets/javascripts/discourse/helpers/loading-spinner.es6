import ConditionalLoadingSpinner from 'discourse/components/conditional-loading-spinner';

function renderSpinner(cssClass) {
  var html = "<div class='spinner";
  if (cssClass) { html += ' ' + cssClass; }
  return html + "'></div>";
}
var spinnerHTML = renderSpinner();

/**
   If you use it as a regular helper {{loading-spinner}} you'll just get the
   HTML for a spinner.

   If you provide an `condition=xyz` parameter, it will be bound to that property
   and only show when it's truthy.

   If you use the block form `{{#loading-spinner}} ... {{/loading-spinner}`,
   the contents will shown when the loading condition finishes.
 **/
Handlebars.registerHelper('loading-spinner', function(options) {
  var hash = options.hash;
  if (hash && hash.condition) {
    var types = options.hashTypes;
    Discourse.Utilities.normalizeHash(hash, types);
    return Ember.Handlebars.helpers.view.call(this, ConditionalLoadingSpinner, options);
  } else {
    return new Handlebars.SafeString(renderSpinner((hash && hash.size) ? hash.size : undefined));
  }
});

export { spinnerHTML, renderSpinner };
