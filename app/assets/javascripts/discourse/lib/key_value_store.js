/**
  A simple key value store that uses LocalStorage

  @class KeyValueStore
  @namespace Discourse
  @module Discourse
**/
Discourse.KeyValueStore = {
  initialized: false,
  context: "",
  listeners: {},

  init: function(ctx) {
    this.initialized = true;
    this.context = ctx;
    window.onstorage = this.handleStorageEvent.bind(this);
  },

  abandonLocal: function() {
    var i, k;
    if (!(localStorage && this.initialized)) {
      return false;
    }
    i = localStorage.length - 1;
    while (i >= 0) {
      k = localStorage.key(i);
      if (k.substring(0, this.context.length) === this.context) {
        localStorage.removeItem(k);
      }
      i--;
    }
    return true;
  },

  remove: function(key) {
    return localStorage.removeItem(this.context + key);
  },

  set: function(opts) {
    if (!(localStorage && this.initialized)) {
      return false;
    }
    localStorage[this.context + opts.key] = opts.value;
  },

  get: function(key) {
    if (!localStorage) {
      return null;
    }
    return localStorage[this.context + key];
  },

  // listens on the key being changed.
  // callback will be called with arguments (oldValue, newValue)
  // returns true on success, false if callback is not a function
  listen: function(key, callback) {
    if (typeof(callback) !== 'function') {
      return false;
    }
    if (this.listeners[key] === undefined) {
      this.listeners[key] = [callback];
    } else {
      this.listeners[key].push(callback);
    }
    return true;
  },

  handleStorageEvent: function(event) {
    var key = event.key;
    if (key.indexOf(this.context) === 0) {
      key = key.substring(this.context.length);
    } else {
      // Not our context, not our responsibility
      return true;
    }
    var targets = this.listeners[key];
    if (!targets) {
      return false;
    }
    Em.run(function() {
      targets.forEach(function(listener){
        listener(event.oldValue, event.newValue);
      });
    });
    return false;
  }
};

