Ember.Handlebars.registerBoundHelper("boundI18n", function(property, options) {
  return new Handlebars.SafeString(I18n.t(property, options.hash));
});

