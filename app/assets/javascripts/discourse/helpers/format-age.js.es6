Handlebars.registerHelper('format-age', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(dt));
});
