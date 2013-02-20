
/* key value store
*/


(function() {

  window.Discourse.KeyValueStore = (function() {
    var context, initialized;
    initialized = false;
    context = "";
    return {
      init: function(ctx, messageBus) {
        initialized = true;
        context = ctx;
      },
      abandonLocal: function() {
        var i, k;
        if (!(localStorage && initialized)) {
          return;
        }
        i = localStorage.length - 1;
        while (i >= 0) {
          k = localStorage.key(i);
          if (k.substring(0, context.length) === context) {
            localStorage.removeItem(k);
          }
          i--;
        }
        return true;
      },
      remove: function(key) {
        return localStorage.removeItem(context + key);
      },
      set: function(opts) {
        if (!(localStorage && initialized)) {
          return false;
        }
        localStorage[context + opts.key] = opts.value;
      },
      get: function(key) {
        if (!localStorage) {
          return null;
        }
        return localStorage[context + key];
      }
    };
  })();

}).call(this);
