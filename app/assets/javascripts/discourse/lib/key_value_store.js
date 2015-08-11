/**
  A simple key value store that uses LocalStorage

  @class KeyValueStore
  @namespace Discourse
  @module Discourse
**/


var safeLocalStorage;

try {
  safeLocalStorage = localStorage;
  if (localStorage["disableLocalStorage"] === "true") {
    safeLocalStorage = null;
  }
} catch(e){
 // cookies disabled, we don't care
 safeLocalStorage = null;
}

Discourse.KeyValueStore = {
  initialized: false,
  context: "",

  init: function(ctx) {
    this.initialized = true;
    this.context = ctx;
  },

  abandonLocal: function() {
    var i, k;
    if (!(safeLocalStorage && this.initialized)) {
      return;
    }
    i = safeLocalStorage.length - 1;
    while (i >= 0) {
      k = safeLocalStorage.key(i);
      if (k.substring(0, this.context.length) === this.context) {
        safeLocalStorage.removeItem(k);
      }
      i--;
    }
    return true;
  },

  remove: function(key) {
    return safeLocalStorage.removeItem(this.context + key);
  },

  set: function(opts) {
    if (!safeLocalStorage && this.initialized) {
      return false;
    }
    safeLocalStorage[this.context + opts.key] = opts.value;
  },

  get: function(key) {
    if (!safeLocalStorage) {
      return null;
    }
    return safeLocalStorage[this.context + key];
  }
};

