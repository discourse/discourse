/**
  A simple key value store that uses LocalStorage

  @class KeyValueStore
  @namespace Discourse
  @module Discourse
**/
Discourse.KeyValueStore = {
  initialized: false,
  context: "",

  init: function(ctx, messageBus) {
    this.initialized = true;
    this.context = ctx;
  },

  abandonLocal: function() {
    var i, k;
    if (!(localStorage && this.initialized)) {
      return;
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
  }
};

