const get = Discourse.EmberCompatHandlebars.get;

function resolveParams(ctx, options) {
  let params = {};
  const hash = options.hash;

  if (hash) {
    if (options.hashTypes) {
      Ember.keys(hash).forEach(function(k) {
        const type = options.hashTypes[k];
        if (type === "STRING") {
          params[k] = hash[k];
        } else if (type === "ID") {
          params[k] = get(ctx, hash[k], options);
        }
      });
    } else {
      params = hash;
    }
  }
  return params;
}

export default function registerUnbound(name, fn) {
  const func = function(property, options) {
    if (options.types && options.types[0] === "ID") {
      property = get(this, property, options);
    }

    return fn.call(this, property, resolveParams(this, options));
  };

  Handlebars.registerHelper(name, func);
  Ember.Handlebars.registerHelper(name, func);
}
