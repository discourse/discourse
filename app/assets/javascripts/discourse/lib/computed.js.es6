import addonFmt from "ember-addons/fmt";

/**
  Returns whether two properties are equal to each other.

  @method propertyEqual
  @params {String} p1 the first property
  @params {String} p2 the second property
  @return {Function} discourseComputedProperty function
**/

export function propertyEqual(p1, p2) {
  return Ember.computed(p1, p2, function() {
    return this.get(p1) === this.get(p2);
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
  return Ember.computed(p1, p2, function() {
    return this.get(p1) !== this.get(p2);
  });
}

export function propertyGreaterThan(p1, p2) {
  return Ember.computed(p1, p2, function() {
    return this.get(p1) > this.get(p2);
  });
}

export function propertyLessThan(p1, p2) {
  return Ember.computed(p1, p2, function() {
    return this.get(p1) < this.get(p2);
  });
}

/**
  Returns i18n version of a string based on a property.

  @method i18n
  @params {String} properties* to format
  @params {String} format the i18n format string
  @return {Function} discourseComputedProperty function
**/
export function i18n(...args) {
  const format = args.pop();
  return Ember.computed(...args, function() {
    return I18n.t(addonFmt(format, ...args.map(a => this.get(a))));
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
  return Ember.computed(...args, function() {
    return addonFmt(format, ...args.map(a => this.get(a)));
  });
}

/**
  Creates a URL using Discourse.getURL. It takes a fmt string just like
  fmt does.

  @method url
  @params {String} properties* to format
  @params {String} format the format string for the URL
  @return {Function} discourseComputedProperty function returning a URL
**/
export function url(...args) {
  const format = args.pop();
  return Ember.computed(...args, function() {
    return Discourse.getURL(addonFmt(format, ...args.map(a => this.get(a))));
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
  return Ember.computed(...args, function() {
    return args
      .map(a => this.get(a))
      .every(s => {
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
  return Ember.computed(function() {
    return Discourse.SiteSettings[name];
  });
}
