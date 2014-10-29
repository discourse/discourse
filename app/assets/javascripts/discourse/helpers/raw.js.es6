Handlebars.registerHelper('raw', function(property, options) {
  var template = Discourse.__container__.lookup('template:' + property + ".raw"),
      params = options.hash;

  if (params) {
    for (var prop in params) {
      if (options.hashTypes[prop] === "ID") {
        params[prop] = Em.Handlebars.get(this, params[prop], options);
      }
    }
  }

  return new Handlebars.SafeString(template(params));
});
