Handlebars.registerHelper('raw', function(property, options) {
  var templateName = property + ".raw",
      template = Discourse.__container__.lookup('template:' + templateName),
      params = options.hash;

  if (!template) {
    Ember.warn('Could not find raw template: ' + templateName);
    return;
  }

  if (params) {
    for (var prop in params) {
      if (options.hashTypes[prop] === "ID") {
        params[prop] = Ember.Handlebars.get(this, params[prop], options);
      }
    }
  }

  return new Handlebars.SafeString(template(params));
});
