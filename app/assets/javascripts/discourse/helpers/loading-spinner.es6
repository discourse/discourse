import ConditionalLoadingSpinner from 'discourse/components/conditional-loading-spinner';
var spinnerHTML = "<div class='spinner'></div>";

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
    var html = spinnerHTML;
    if (hash && hash.class) {
      html = "<div class='spinner " + hash.class + "'></div>";
    }
    return new Handlebars.SafeString(html);
  }
});

export { spinnerHTML };
