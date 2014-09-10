Handlebars.registerHelper('shorten-text', function(property, options) {
  return Ember.Handlebars.get(this, property, options).substring(0,35);
});
