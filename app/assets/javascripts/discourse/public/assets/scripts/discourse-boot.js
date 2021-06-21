(function () {
  // TODO: These are needed to load plugins because @ember has its own loader.
  // We should find a nicer way to do this.
  const EMBER_MODULES = {
    "@ember/application": {
      default: Ember.Application,
      setOwner: Ember.setOwner,
      getOwner: Ember.getOwner,
    },
    "@ember/array": {
      default: Ember.Array,
      A: Ember.A,
      isArray: Ember.isArray,
    },
    "@ember/array/proxy": {
      default: Ember.ArrayProxy,
    },
    "@ember/component": {
      default: Ember.Component,
    },
    "@ember/component/helper": {
      default: Ember.Helper,
    },
    "@ember/component/text-field": {
      default: Ember.TextField,
    },
    "@ember/component/text-area": {
      default: Ember.TextArea,
    },
    "@ember/controller": {
      default: Ember.Controller,
      inject: Ember.inject.controller,
    },
    "@ember/debug": {
      warn: Ember.warn,
    },
    "@ember/error": {
      default: Ember.error,
    },
    "@ember/object": {
      action: Ember._action,
      default: Ember.Object,
      get: Ember.get,
      getProperties: Ember.getProperties,
      set: Ember.set,
      setProperties: Ember.setProperties,
      computed: Ember.computed,
      defineProperty: Ember.defineProperty,
    },
    "@ember/object/computed": {
      alias: Ember.computed.alias,
      and: Ember.computed.and,
      bool: Ember.computed.bool,
      collect: Ember.computed.collect,
      deprecatingAlias: Ember.computed.deprecatingAlias,
      empty: Ember.computed.empty,
      equal: Ember.computed.equal,
      filter: Ember.computed.filter,
      filterBy: Ember.computed.filterBy,
      gt: Ember.computed.gt,
      gte: Ember.computed.gte,
      intersect: Ember.computed.intersect,
      lt: Ember.computed.lt,
      lte: Ember.computed.lte,
      map: Ember.computed.map,
      mapBy: Ember.computed.mapBy,
      match: Ember.computed.match,
      max: Ember.computed.max,
      min: Ember.computed.min,
      none: Ember.computed.none,
      not: Ember.computed.not,
      notEmpty: Ember.computed.notEmpty,
      oneWay: Ember.computed.oneWay,
      or: Ember.computed.or,
      readOnly: Ember.computed.readOnly,
      reads: Ember.computed.reads,
      setDiff: Ember.computed.setDiff,
      sort: Ember.computed.sort,
      sum: Ember.computed.sum,
      union: Ember.computed.union,
      uniq: Ember.computed.uniq,
      uniqBy: Ember.computed.uniqBy,
    },
    "@ember/object/internals": {
      guidFor: Ember.guidFor,
    },
    "@ember/object/mixin": { default: Ember.Mixin },
    "@ember/object/proxy": { default: Ember.ObjectProxy },
    "@ember/object/promise-proxy-mixin": { default: Ember.PromiseProxyMixin },
    "@ember/object/evented": {
      default: Ember.Evented,
      on: Ember.on,
    },
    "@ember/routing/route": { default: Ember.Route },
    "@ember/routing/router": { default: Ember.Router },
    "@ember/runloop": {
      bind: Ember.run.bind,
      cancel: Ember.run.cancel,
      debounce: Ember.testing ? Ember.run : Ember.run.debounce,
      later: Ember.run.later,
      next: Ember.run.next,
      once: Ember.run.once,
      run: Ember.run,
      schedule: Ember.run.schedule,
      scheduleOnce: Ember.run.scheduleOnce,
      throttle: Ember.run.throttle,
    },
    "@ember/service": {
      default: Ember.Service,
      inject: Ember.inject.service,
    },
    "@ember/string": {
      w: Ember.String.w,
      dasherize: Ember.String.dasherize,
      decamelize: Ember.String.decamelize,
      camelize: Ember.String.camelize,
      classify: Ember.String.classify,
      underscore: Ember.String.underscore,
      capitalize: Ember.String.capitalize,
    },
    "@ember/template": {
      htmlSafe: Ember.String.htmlSafe,
    },
    "@ember/utils": {
      isBlank: Ember.isBlank,
      isEmpty: Ember.isEmpty,
      isNone: Ember.isNone,
      isPresent: Ember.isPresent,
    },
    jquery: { default: $ },
    rsvp: {
      asap: Ember.RSVP.asap,
      all: Ember.RSVP.all,
      allSettled: Ember.RSVP.allSettled,
      race: Ember.RSVP.race,
      hash: Ember.RSVP.hash,
      hashSettled: Ember.RSVP.hashSettled,
      rethrow: Ember.RSVP.rethrow,
      defer: Ember.RSVP.defer,
      denodeify: Ember.RSVP.denodeify,
      resolve: Ember.RSVP.resolve,
      reject: Ember.RSVP.reject,
      map: Ember.RSVP.map,
      filter: Ember.RSVP.filter,
      default: Ember.RSVP,
      Promise: Ember.RSVP.Promise,
      EventTarget: Ember.RSVP.EventTarget,
    },
  };
  Object.keys(EMBER_MODULES).forEach((mod) => {
    define(mod, () => EMBER_MODULES[mod]);
  });

  // TODO: Remove this and have resolver find the templates
  const prefix = "discourse/templates/";
  const adminPrefix = "admin/templates/";
  let len = prefix.length;
  Object.keys(requirejs.entries).forEach(function (key) {
    if (key.indexOf(prefix) === 0) {
      Ember.TEMPLATES[key.substr(len)] = require(key).default;
    } else if (key.indexOf(adminPrefix) === 0) {
      Ember.TEMPLATES[key] = require(key).default;
    }
  });

  define("I18n", ["exports"], function (exports) {
    return I18n;
  });

  define("htmlbars-inline-precompile", ["exports"], function (exports) {
    exports.default = function tag(strings) {
      return Ember.Handlebars.compile(strings[0]);
    };
  });
  window.__widget_helpers = require("discourse-widget-hbs/helpers").default;

  // TODO: Eliminate this global
  window.virtualDom = require("virtual-dom");

  let element = document.querySelector(
    `meta[name="discourse/config/environment"]`
  );
  const config = JSON.parse(
    decodeURIComponent(element.getAttribute("content"))
  );
  const event = new CustomEvent("discourse-booted", { detail: config });
  document.dispatchEvent(event);
})();
