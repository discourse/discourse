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
  const func = function(property, options) {
    if (
      options.types &&
      (options.types[0] === "ID" || options.types[0] === "PathExpression")
    ) {
      property = get(this, property, options);
    }

    return fn.call(this, property, resolveParams(this, options));
  };

  _helpers[name] = Ember.Helper.extend({
    compute: (params, args) => fn(params[0], args)
  });
  Handlebars.registerHelper(name, func);
}
