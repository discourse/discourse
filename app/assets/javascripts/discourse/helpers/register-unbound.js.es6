var get = Discourse.EmberCompatHandlebars.get;

export default function registerUnbound(name, fn) {
  Handlebars.registerHelper(name, function(property, options) {

    if (options.types[0] === "ID") {
      property = get(this, property, options);
    }

    var params = {},
        hash = options.hash;

    if (hash) {
      var self = this;
      Ember.keys(options.hash).forEach(function(k) {
        var type = options.hashTypes[k];
        if (type === "STRING") {
          params[k] = hash[k];
        } else if (type === "ID") {
          params[k] = get(self, hash[k], options);
        }
      });
    }

    return fn(property, params);
  });
}
