import { get } from "discourse-common/lib/raw-handlebars";

export function htmlHelper(fn) {
  return Ember.Helper.helper(function(...args) {
    args =
      args.length > 1 ? args[0].concat({ hash: args[args.length - 1] }) : args;
    return new Handlebars.SafeString(fn.apply(this, args) || "");
  });
}

const _helpers = {};

export function registerHelper(name, fn) {
  _helpers[name] = Ember.Helper.helper(fn);
}

export function findHelper(name) {
  return _helpers[name] || _helpers[name.dasherize()];
}

export function registerHelpers(registry) {
  Object.keys(_helpers).forEach(name => {
    registry.register(`helper:${name}`, _helpers[name], { singleton: false });
  });
}

function resolveParams(ctx, options) {
  let params = {};
  const hash = options.hash;

  if (hash) {
    if (options.hashTypes) {
      Object.keys(hash).forEach(function(k) {
        const type = options.hashTypes[k];
        if (type === "STRING" || type === "StringLiteral") {
          params[k] = hash[k];
        } else if (type === "ID" || type === "PathExpression") {
          params[k] = get(ctx, hash[k], options);
        }
      });
    } else {
      params = hash;
    }
  }
  return params;
}

export function registerUnbound(name, fn) {
  const func = function(...args) {
    const options = args.pop();
    const properties = args;

    for (let i = 0; i < properties.length; i++) {
      if (
        options.types &&
        (options.types[i] === "ID" || options.types[i] === "PathExpression")
      ) {
        properties[i] = get(this, properties[i], options);
      }
    }

    return fn.call(this, ...properties, resolveParams(this, options));
  };

  _helpers[name] = Ember.Helper.extend({
    compute: (params, args) => fn(...params, args)
  });
  Handlebars.registerHelper(name, func);
}
