import { computed } from "@ember/object";
import { htmlSafe as htmlSafeTemplateHelper } from "@ember/template";
import getURL from "discourse-common/lib/get-url";
import { deepEqual } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

function addonFmt(str, formats) {
  let cachedFormats = formats;

  if (!Array.isArray(cachedFormats) || arguments.length > 2) {
    cachedFormats = new Array(arguments.length - 1);

    for (let i = 1, l = arguments.length; i < l; i++) {
      cachedFormats[i - 1] = arguments[i];
    }
  }

  // first, replace any ORDERED replacements.
  let idx = 0; // the current index for non-numerical replacements
  return str.replace(/%@([0-9]+)?/g, function (s, argIndex) {
    argIndex = argIndex ? parseInt(argIndex, 10) - 1 : idx++;
    s = cachedFormats[argIndex];
    return typeof s === "string"
      ? s
      : s === null
      ? "(null)"
      : s === undefined
      ? ""
      : "" + s;
  });
}
/**
  Returns whether two properties are equal to each other.

  @method propertyEqual
  @params {String} p1 the first property
  @params {String} p2 the second property
  @return {Function} discourseComputedProperty function
**/

export function propertyEqual(p1, p2) {
  return computed(p1, p2, function () {
    return deepEqual(this.get(p1), this.get(p2));
  });
}

/**
  Returns whether two properties are not equal to each other.

  @method propertyNotEqual
  @params {String} p1 the first property
  @params {String} p2 the second property
  @return {Function} discourseComputedProperty function
**/
export function propertyNotEqual(p1, p2) {
  return computed(p1, p2, function () {
    return !deepEqual(this.get(p1), this.get(p2));
  });
}

export function propertyGreaterThan(p1, p2) {
  return computed(p1, p2, function () {
    return this.get(p1) > this.get(p2);
  });
}

export function propertyLessThan(p1, p2) {
  return computed(p1, p2, function () {
    return this.get(p1) < this.get(p2);
  });
}

/**
  Returns i18n version of a string based on a property.

  @method computedI18n
  @params {String} properties* to format
  @params {String} format the i18n format string
  @return {Function} discourseComputedProperty function
**/
export function computedI18n(...args) {
  const format = args.pop();
  return computed(...args, function () {
    return i18n(addonFmt(format, ...args.map((a) => this.get(a))));
  });
}

export { computedI18n as i18n };

/**
  Returns htmlSafe version of a string.

  @method htmlSafe
  @params {String} properties* to htmlify
  @return {Function} discourseComputedProperty function
**/
export function htmlSafe(...args) {
  return computed(...args, {
    get() {
      const path = args.pop();
      return htmlSafeTemplateHelper(this.get(path));
    },
  });
}

/**
  Uses an Ember String `fmt` call to format a string. See:
  http://emberjs.com/api/classes/Ember.String.html#method_fmt

  @method fmt
  @params {String} properties* to format
  @params {String} format the format string
  @return {Function} discourseComputedProperty function
**/
export function fmt(...args) {
  const format = args.pop();
  return computed(...args, function () {
    return addonFmt(format, ...args.map((a) => this.get(a)));
  });
}

/**
  Creates a URL using getURL. It takes a fmt string just like
  fmt does.

  @method url
  @params {String} properties* to format
  @params {String} format the format string for the URL
  @return {Function} discourseComputedProperty function returning a URL
**/
export function url(...args) {
  const format = args.pop();
  return computed(...args, function () {
    return getURL(addonFmt(format, ...args.map((a) => this.get(a))));
  });
}

/**
  Returns whether properties end with a string

  @method endWith
  @params {String} properties* to check
  @params {String} substring the substring
  @return {Function} discourseComputedProperty function
**/
export function endWith() {
  const args = Array.prototype.slice.call(arguments, 0);
  const substring = args.pop();
  return computed(...args, function () {
    return args
      .map((a) => this.get(a))
      .every((s) => {
        const position = s.length - substring.length,
          lastIndex = s.lastIndexOf(substring);
        return lastIndex !== -1 && lastIndex === position;
      });
  });
}

/**
  Creates a property from a SiteSetting. In the future the plan is for them to
  be able to update when changed.

  @method setting
  @param {String} name of site setting
**/
export function setting(name) {
  return computed(function () {
    return this.siteSettings[name];
  });
}
