import Helper from "@ember/component/helper";
import { get } from "@ember/object";
import { dasherize } from "@ember/string";
import { htmlSafe } from "@ember/template";
import deprecated from "discourse/lib/deprecated";
import RawHandlebars from "discourse/lib/raw-handlebars";

export function makeArray(obj) {
  if (obj === null || obj === undefined) {
    return [];
  }
  return Array.isArray(obj) ? obj : [obj];
}

export function htmlHelper(fn) {
  deprecated(
    `htmlHelper is deprecated. Use a plain function and \`htmlSafe()\` from "@ember/template" instead.`,
    { id: "discourse.html-helper" }
  );

  return Helper.helper(function (...args) {
    args =
      args.length > 1 ? args[0].concat({ hash: args[args.length - 1] }) : args;
    return htmlSafe(fn.apply(this, args) || "");
  });
}

const _helpers = {};

function rawGet(ctx, property, options) {
  if (options.types && options.data.view) {
    let view = options.data.view;
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
  return _helpers[name] || _helpers[dasherize(name)];
}

export function registerHelpers(registry) {
  Object.keys(_helpers).forEach((name) => {
    registry.register(`helper:${name}`, _helpers[name], { singleton: false });
  });
}

let _helperContext;
export function createHelperContext(ctx) {
  _helperContext = ctx;
}

// This can be used by a helper to get the SiteSettings. Note you should not
// be using it outside of helpers (or lib code that helpers use!)
export function helperContext() {
  return _helperContext;
}

function resolveParams(ctx, options) {
  let params = {};
  const hash = options.hash;

  if (hash) {
    if (options.hashTypes) {
      Object.keys(hash).forEach(function (k) {
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

/**
 * Register a helper for Ember and raw-hbs. This exists for
 * legacy reasons, and should be avoided in new code. Instead, you should
 * do `export default ...` from a `helpers/*.js` file.
 */
export function registerUnbound(name, fn) {
  deprecated(
    `[registerUnbound ${name}] registerUnbound is deprecated. Instead, you should export a default function from 'discourse/helpers/${name}.js'. If the helper is also used in raw-hbs, you can register it using 'registerRawHelper'.`,
    { id: "discourse.register-unbound" }
  );

  _helpers[name] = class extends Helper {
    compute(params, args) {
      return fn(...params, args);
    }
  };

  registerRawHelper(name, fn);
}

/**
 * Register a helper for raw-hbs only
 */
export function registerRawHelper(name, fn) {
  const func = function (...args) {
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

  RawHandlebars.registerHelper(name, func);
}
