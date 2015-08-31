/**
  Returns whether two properties are equal to each other.

  @method propertyEqual
  @params {String} p1 the first property
  @params {String} p2 the second property
  @return {Function} computedProperty function
**/
export function propertyEqual(p1, p2) {
  return Em.computed(function() {
    return this.get(p1) === this.get(p2);
  }).property(p1, p2);
}

/**
  Returns whether two properties are not equal to each other.

  @method propertyNotEqual
  @params {String} p1 the first property
  @params {String} p2 the second property
  @return {Function} computedProperty function
**/
export function propertyNotEqual(p1, p2) {
  return Em.computed(function() {
    return this.get(p1) !== this.get(p2);
  }).property(p1, p2);
}

export function propertyGreaterThan(p1, p2) {
  return Ember.computed(function() {
    return this.get(p1) > this.get(p2);
  }).property(p1, p2);
}

export function propertyLessThan(p1, p2) {
  return Ember.computed(function() {
    return this.get(p1) < this.get(p2);
  }).property(p1, p2);
}

/**
  Returns i18n version of a string based on a property.

  @method i18n
  @params {String} properties* to format
  @params {String} format the i18n format string
  @return {Function} computedProperty function
**/
export function i18n() {
  const args = Array.prototype.slice.call(arguments, 0);
  const format = args.pop();
  const computed = Em.computed(function() {
    const self = this;
    return I18n.t(format.fmt.apply(format, args.map(function (a) {
      return self.get(a);
    })));
  });
  return computed.property.apply(computed, args);
}

/**
  Uses an Ember String `fmt` call to format a string. See:
  http://emberjs.com/api/classes/Em.String.html#method_fmt

  @method fmt
  @params {String} properties* to format
  @params {String} format the format string
  @return {Function} computedProperty function
**/
export function fmt() {
  const args = Array.prototype.slice.call(arguments, 0);
  const format = args.pop();
  const computed = Em.computed(function() {
    const self = this;
    return format.fmt.apply(format, args.map(function (a) {
      return self.get(a);
    }));
  });
  return computed.property.apply(computed, args);
}

/**
  Creates a URL using Discourse.getURL. It takes a fmt string just like
  fmt does.

  @method url
  @params {String} properties* to format
  @params {String} format the format string for the URL
  @return {Function} computedProperty function returning a URL
**/
export function url() {
  const args = Array.prototype.slice.call(arguments, 0);
  const format = args.pop();
  const computed = Em.computed(function() {
    const self = this;
    return Discourse.getURL(format.fmt.apply(format, args.map(function (a) {
      return self.get(a);
    })));
  });
  return computed.property.apply(computed, args);
}

/**
  Returns whether properties end with a string

  @method endWith
  @params {String} properties* to check
  @params {String} substring the substring
  @return {Function} computedProperty function
**/
export function endWith() {
  const args = Array.prototype.slice.call(arguments, 0);
  const substring = args.pop();
  const computed = Em.computed(function() {
    const self = this;
    return _.all(args.map(function(a) { return self.get(a); }), function(s) {
      const position = s.length - substring.length,
          lastIndex = s.lastIndexOf(substring);
      return lastIndex !== -1 && lastIndex === position;
    });
  });
  return computed.property.apply(computed, args);
}

/**
  Creates a property from a SiteSetting. In the future the plan is for them to
  be able to update when changed.

  @method setting
  @param {String} name of site setting
**/
export function setting(name) {
  return Em.computed(function() {
    return Discourse.SiteSettings[name];
  }).property();
}
