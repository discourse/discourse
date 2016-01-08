Ember.Handlebars.registerBoundHelper("capitalize", function(str) {
  return str[0].toUpperCase() + str.slice(1);
});
