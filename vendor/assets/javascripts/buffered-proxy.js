(function (global) {
  "use strict";

  function aliasMethod(methodName) {
    return function() {
      return this[methodName].apply(this, arguments);
    };
  }

  function empty(obj) {
    var key;
    for (key in obj) if (obj.hasOwnProperty(key)) return false;
    return true;
  }

  var Ember = global.Ember,
      get = Ember.get, set = Ember.set,
      isArray = Ember.isArray, getProperties = Ember.getProperties,
      notifyPropertyChange = Ember.notifyPropertyChange,
      meta = Ember.meta, defineProperty = Ember.defineProperty;

  var hasOwnProp = Object.prototype.hasOwnProperty;

  var BufferedProxyMixin = Ember.Mixin.create({
    buffer: null,
    hasBufferedChanges: false,

    hasChanges: Ember.computed.readOnly('hasBufferedChanges'),

    applyChanges: function() {
      return this.applyBufferedChanges(...arguments);
    },

    discardChanges: function() {
      return this.discardBufferedChanges(...arguments);
    },

    init: function() {
      this.initializeBuffer();
      set(this, 'hasBufferedChanges', false);
      this._super(...arguments);
    },

    initializeBuffer: function(onlyTheseKeys) {
      if(isArray(onlyTheseKeys) && !empty(onlyTheseKeys)) {
        onlyTheseKeys.forEach((key) => delete this.buffer[key]);
      }
      else {
        set(this, 'buffer', Object.create(null));
      }
    },

    unknownProperty: function(key) {
      var buffer = get(this, 'buffer');
      return (hasOwnProp.call(buffer, key)) ? buffer[key] : this._super(key);
    },

    setUnknownProperty: function(key, value) {
      var m = meta(this);

      if (m.proto === this || (m.isInitializing && m.isInitializing())) {
        defineProperty(this, key, null, value);
        return value;
      }

      var props = getProperties(this, ['buffer', 'content']),
          buffer = props.buffer,
          content = props.content,
          current,
          previous;

      if (content != null) {
        current = get(content, key);
      }

      previous = hasOwnProp.call(buffer, key) ? buffer[key] : current;

      if (previous === value) {
        return;
      }

      if (current === value) {
        delete buffer[key];
        if (empty(buffer)) {
          set(this, 'hasBufferedChanges', false);
        }
      } else {
        buffer[key] = value;
        set(this, 'hasBufferedChanges', true);
      }

      notifyPropertyChange(content, key);

      return value;
    },

    applyBufferedChanges: function(onlyTheseKeys) {
      var props = getProperties(this, ['buffer', 'content']),
          buffer = props.buffer,
          content = props.content,
          key;

      Object.keys(buffer).forEach((key) => {
        if (isArray(onlyTheseKeys) && onlyTheseKeys.indexOf(key) === -1) {
          return;
        }

        set(content, key, buffer[key]);
      });

      this.initializeBuffer(onlyTheseKeys);

      if (empty(get(this, 'buffer'))) {
        set(this, 'hasBufferedChanges', false);
      }
    },

    discardBufferedChanges: function(onlyTheseKeys) {
      var props = getProperties(this, ['buffer', 'content']),
          buffer = props.buffer,
          content = props.content,
          key;

      this.initializeBuffer(onlyTheseKeys);

      Object.keys(buffer).forEach((key) => {
        if (isArray(onlyTheseKeys) && onlyTheseKeys.indexOf(key) === -1) {
          return;
        }

        notifyPropertyChange(content, key);
      });

      if (empty(get(this, 'buffer'))) {
        set(this, 'hasBufferedChanges', false);
      }
    },

    hasChanged: function(key) {
      var props = getProperties(this, ['buffer', 'content']),
          buffer = props.buffer,
          content = props.content,
          key;

      if (typeof key !== 'string' || typeof get(buffer, key) === 'undefined') {
        return false;
      }

      if (get(buffer, key) !== get(content, key)) {
        return true;
      }

      return false;
    }
  });

  var BufferedProxy = Ember.ObjectProxy.extend(BufferedProxyMixin);

  // CommonJS module
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = BufferedProxy;
  } else if (typeof define === "function" && define.amd) {
    define("ember-buffered-proxy/proxy", function (require, exports, module) {
      return BufferedProxy;
    });
  } else {
    global.BufferedProxy = BufferedProxy;
  }
}(this));
