import { get } from "@ember/object";
import Helper from "@ember/component/helper";
import RawHandlebars from "discourse-common/lib/raw-handlebars";

export function makeArray(obj) {
  if (obj === null || obj === undefined) {
    return [];
  }
  return Array.isArray(obj) ? obj : [obj];
}

export function htmlHelper(fn) {
  return Helper.helper(function(...args) {
    args =
      args.length > 1 ? args[0].concat({ hash: args[args.length - 1] }) : args;
    return new Handlebars.SafeString(fn.apply(this, args) || "");
  });
}

const _helpers = {};

function rawGet(ctx, property, options) {
  if (options.types && options.data.view) {
    var view = options.data.view;
    return view.getStream
      ? view.getStream(property).value()
      : view.getAttr(property);
  } else {
    return get(ctx, property);
  }
}

export function registerHelper(name, fn) {
  _helpers[name] = Helper.helper(fn);
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
        if (
          type === "STRING" ||
          type === "StringLiteral" ||
          type === "SubExpression"
        ) {
          params[k] = hash[k];
        } else if (type === "ID" || type === "PathExpression") {
          params[k] = rawGet(ctx, hash[k], options);
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
        properties[i] = rawGet(this, properties[i], options);
      }
    }

    return fn.call(this, ...properties, resolveParams(this, options));
  };

  _helpers[name] = Helper.extend({
    compute: (params, args) => fn(...params, args)
  });
  RawHandlebars.registerHelper(name, func);
}
