(function (global) {
  "use strict";

  function empty(obj) {
    var key;
    for (key in obj) if (obj.hasOwnProperty(key)) return false;
    return true;
  }

  var Ember = global.Ember,
      get = Ember.get, set = Ember.set;

  var BufferedProxy = Ember.Mixin.create({
    buffer: null,

    hasBufferedChanges: false,

    unknownProperty: function (key) {
      var buffer = this.buffer;
      return buffer && buffer.hasOwnProperty(key) ? buffer[key] : this._super(key);
    },

    setUnknownProperty: function (key, value) {
      if (!this.buffer) this.buffer = {};

      var buffer = this.buffer,
          content = this.get('content'),
          current = content && get(content, key),
          previous = buffer.hasOwnProperty(key) ? buffer[key] : current;

      if (previous === value) return;

      if (current === value) {
        delete buffer[key];
        if (empty(buffer)) {
          this.set('hasBufferedChanges', false);
        }
      } else {
        buffer[key] = value;
        this.set('hasBufferedChanges', true);
      }

      this.notifyPropertyChange(key);
      return value;
    },

    applyBufferedChanges: function() {
      var buffer = this.buffer,
          content = this.get('content'),
          key;
      for (key in buffer) {
        if (!buffer.hasOwnProperty(key)) continue;
        set(content, key, buffer[key]);
      }
      this.buffer = {};
      this.set('hasBufferedChanges', false);
    },

    discardBufferedChanges: function() {
      var buffer = this.buffer,
          content = this.get('content'),
          key;
      for (key in buffer) {
        if (!buffer.hasOwnProperty(key)) continue;

        delete buffer[key];
        this.notifyPropertyChange(key);
      }
      this.set('hasBufferedChanges', false);
    }
  });

  // CommonJS module
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = BufferedProxy;
  } else if (typeof define === "function" && define.amd) {
    define("buffered-proxy", function (require, exports, module) {
      return BufferedProxy;
    });
  } else {
    global.BufferedProxy = BufferedProxy;
  }

}(this));
