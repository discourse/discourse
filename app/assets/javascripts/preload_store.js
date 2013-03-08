
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
    To retrieve a key, you provide the key you want, plus a finder to
    load it if the key cannot be found. Once the key is used once, it is
    removed from the store. So, for example, you can't load a preloaded topic
    more than once.

    @method get
    @param {String} key the key to look up the object with
    @param {function} finder a function to find the object with
    @returns {Promise} a promise that will eventually be the object we want.
  **/
  get: function(key, finder) {
    var promise = new RSVP.Promise();

    if (this.data[key]) {
      promise.resolve(this.data[key]);
      delete this.data[key];
    } else {

      if (finder) {
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
      } else {
        promise.resolve(null);
      }
    }
    return promise;
  },

  /**
    Does the store contain a particular key? Does not delete.

    @method contains
    @param {String} key the key to look up the object with
    @returns {Boolean} whether the object exists
  **/
  contains: function(key) {
    return this.data[key] !== void 0;
  },

  /**
    If we are sure it's preloaded, we don't have to supply a finder. Just returns
    undefined if it's not in the store.

    @method getStatic
    @param {String} key the key to look up the object with
    @returns {Object} the object from the store
  **/
  getStatic: function(key) {
    var result = this.data[key];
    delete this.data[key];
    return result;
  }

};
