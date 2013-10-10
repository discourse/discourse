
/**
  We can insert data into the PreloadStore when the document is loaded.
  The data can be accessed once by a key, after which it is removed

  @class PreloadStore
**/
PreloadStore = {
  data: {},

  /**
    Store an object in the store

    @method store
    @param {String} key the key to store the object with
    @param {String} value the object we're inserting into the store
  **/
  store: function(key, value) {
    this.data[key] = value;
  },

  /**
    To retrieve a key, you provide the key you want, plus a finder to load
    it if the key cannot be found. Once the key is used once, it is removed
    from the store.
    So, for example, you can't load a preloaded topic more than once.

    @method getAndRemove
    @param {String} key the key to look up the object with
    @param {function} finder a function to find the object with
    @returns {Ember.Deferred} a promise that will eventually be the object we want.
  **/
  getAndRemove: function(key, finder) {
    if (this.data[key]) {
      var promise = Ember.RSVP.resolve(this.data[key]);
      delete this.data[key];
      return promise;
    }

    if (finder) {
      return Ember.Deferred.promise(function(promise) {
        var result = finder();

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
      });
    }

    return Ember.RSVP.resolve(null);
  },

  /**
    If we are sure it's preloaded, we don't have to supply a finder.
    Just returns undefined if it's not in the store.

    @method get
    @param {String} key the key to look up the object with
    @returns {Object} the object from the store
  **/
  "get": function(key) {
    return this.data[key];
  },

  /**
    Removes the stored value if the key exists

    @method remove
    @param {String} key the key to remove
  **/
  remove: function(key) {
    if (this.data[key]) delete this.data[key];
  }

};
