(function() {

  window.Discourse.Draft = Discourse.Model.extend({});

  Discourse.Draft.reopenClass({
    clear: function(key, sequence) {
      return jQuery.ajax({
        type: 'DELETE',
        url: "/draft",
        data: {
          draft_key: key,
          sequence: sequence
        }
      });
      /* Discourse.KeyValueStore.remove("draft_#{key}")
      */

    },
    get: function(key) {
      var promise,
        _this = this;
      promise = new RSVP.Promise();
      jQuery.ajax({
        url: '/draft',
        data: {
          draft_key: key
        },
        dataType: 'json',
        success: function(data) {
          return promise.resolve(data);
        }
      });
      return promise;
    },
    getLocal: function(key, current) {
      var local;
      return current;
      /* disabling for now to see if it helps with siracusa issue.
        local = Discourse.KeyValueStore.get("draft_" + key);
        if (!current || (local && local.length > current.length)) {
          return local;
        } else {
          return current;
        }
      */
    },
    save: function(key, sequence, data) {
      var promise;
      promise = new RSVP.Promise();
      data = typeof data === "string" ? data : JSON.stringify(data);
      jQuery.ajax({
        type: 'POST',
        url: "/draft",
        data: {
          draft_key: key,
          data: data,
          sequence: sequence
        },
        success: function() {
          /* don't keep local
          */

          /* Discourse.KeyValueStore.remove("draft_#{key}")
          */
          return promise.resolve();
        },
        error: function() {
          /* save local
          */

          /* Discourse.KeyValueStore.set(key: "draft_#{key}", value: data)
          */
          return promise.reject();
        }
      });
      return promise;
    }
  });

}).call(this);
