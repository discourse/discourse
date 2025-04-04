import Helper from "@ember/component/helper";
import { dasherize } from "@ember/string";
import { htmlSafe } from "@ember/template";
import deprecated from "discourse/lib/deprecated";

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

/**
 * Register a helper for Ember and raw-hbs. This exists for
 * legacy reasons, and should be avoided in new code. Instead, you should
 * do `export default ...` from a `helpers/*.js` file.
 */
export function registerUnbound(name, fn) {
  deprecated(
    `[registerUnbound ${name}] registerUnbound is deprecated. Instead, you should export a default function from 'discourse/helpers/${name}.js'.`,
    { id: "discourse.register-unbound" }
  );

  _helpers[name] = class extends Helper {
    compute(params, args) {
      return fn(...params, args);
    }
  };
}

/**
 * Register a helper for raw-hbs only
 */
export function registerRawHelper(name) {
  deprecated(
    `[registerRawHelper ${name}] the raw handlebars system has been removed, so calls to registerRawHelper should be removed.`,
    { id: "discourse.register-raw-helper" }
  );
}
