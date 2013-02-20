
/* We can insert data into the PreloadStore when the document is loaded.
   The data can be accessed once by a key, after which it is removed */
(function() {

  window.PreloadStore = {
    data: {},
    store: function(key, value) {
      this.data[key] = value;
    },
    /* To retrieve a key, you provide the key you want, plus a finder to
       load it if the key cannot be found. Once the key is used once, it is
       removed from the store. So, for example, you can't load a preloaded topic
       more than once. */
    get: function(key, finder) {
      var promise, result;
      promise = new RSVP.Promise();
      if (this.data[key]) {
        promise.resolve(this.data[key]);
        delete this.data[key];
      } else {
        if (finder) {
          result = finder();

          // If the finder returns a promise, we support that too
          if (result.then) {
            result.then(function(result) {
              return promise.resolve(result);
            }, function(result) {
              return promise.reject(result);
            });
          } else {
            promise.resolve(result);
          }
        } else {
          promise.resolve(void 0);
        }
      }
      return promise;
    },
    /* Does the store contain a particular key? Does not delete, just returns
       true or false. */
    contains: function(key) {
      return this.data[key] !== void 0;
    },
    /* If we are sure it's preloaded, we don't have to supply a finder. Just
       returns undefined if it's not in the store. */
    getStatic: function(key) {
      var result;
      result = this.data[key];
      delete this.data[key];
      return result;
    }
  };

}).call(this);
