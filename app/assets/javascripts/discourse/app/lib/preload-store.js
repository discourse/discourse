//  We can insert data into the PreloadStore when the document is loaded.
// The data can be accessed once by a key, after which it is removed
import { Promise } from "rsvp";

export default {
  data: new Map(),

  store(key, value) {
    this.data.set(key, value);
  },

  /**
    To retrieve a key, you provide the key you want, plus a finder to load
    it if the key cannot be found. Once the key is used once, it is removed
    from the store.
    So, for example, you can't load a preloaded topic more than once.
  **/
  getAndRemove(key, finder) {
    if (this.data.has(key)) {
      let promise = Promise.resolve(this.data.get(key));
      this.data.delete(key);
      return promise;
    }

    if (finder) {
      return new Promise(function (resolve, reject) {
        let result = finder();

        // If the finder returns a promise, we support that too
        if (result && result.then) {
          result
            .then((toResolve) => resolve(toResolve))
            .catch((toReject) => reject(toReject));
        } else {
          resolve(result);
        }
      });
    }

    return Promise.resolve(null);
  },

  has(key) {
    return this.data.has(key);
  },

  get(key) {
    return this.data.get(key);
  },

  remove(key) {
    this.data.delete(key);
  },

  reset() {
    this.data = new Map();
  },
};
