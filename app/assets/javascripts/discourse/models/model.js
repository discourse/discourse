(function() {

  window.Discourse.Model = Ember.Object.extend({
    /* Our own AJAX handler that handles erronous responses
    */

    ajax: function(url, args) {
      /* Error handler
      */

      var oldError,
        _this = this;
      oldError = args.error;
      args.error = function(xhr) {
        return oldError(jQuery.parseJSON(xhr.responseText).errors);
      };
      return jQuery.ajax(url, args);
    },
    /* Update our object from another object
    */

    mergeAttributes: function(attrs, builders) {
      var _this = this;
      return Object.keys(attrs, function(k, v) {
        /* If they're in a builder we use that
        */

        var builder, col;
        if (typeof v === 'object' && builders && (builder = builders[k])) {
          if (!_this.get(k)) {
            _this.set(k, Em.A());
          }
          col = _this.get(k);
          return v.each(function(obj) {
            col.pushObject(builder.create(obj));
          });
        } else {
          _this.set(k, v);
        }
      });
    }
  });

  window.Discourse.Model.reopenClass({
    /* Given an array of values, return them in a hash
    */

    extractByKey: function(collection, klass) {
      var retval;
      retval = {};
      if (!collection) {
        return retval;
      }
      collection.each(function(c) {
        var obj;
        obj = klass.create(c);
        retval[c.id] = obj;
      });
      return retval;
    }
  });

}).call(this);
