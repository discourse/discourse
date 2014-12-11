function registerUnbound(name, fn) {
  Handlebars.registerHelper(name, function(property, options) {

    property = Discourse.EmberCompatHandlebars.get(this, property, options);

    var params = {},
        hash = options.hash;

    if (hash) {
      Ember.keys(options.hash).forEach(function(k) {
        var type = options.hashTypes[k];
        if (type === "STRING") {
          params[k] = hash[k];
        } else if (type === "ID") {
          params[k] = options.data.view.getStream(hash[k]).value();
        }
      });
    }

    return fn(property, params);
  });
}

export default registerUnbound;
