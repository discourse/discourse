// A simple key value store that uses LocalStorage
let safeLocalStorage;

try {
  safeLocalStorage = localStorage;
  if (localStorage["disableLocalStorage"] === "true") {
    safeLocalStorage = null;
  }
} catch(e){
  // cookies disabled, we don't care
  safeLocalStorage = null;
}


const KeyValueStore = function(ctx) {
  this.context = ctx;
};

KeyValueStore.prototype = {
  abandonLocal() {
    if (!safeLocalStorage) { return; }

    let i = safeLocalStorage.length - 1;
    while (i >= 0) {
      let k = safeLocalStorage.key(i);
      if (k.substring(0, this.context.length) === this.context) {
        safeLocalStorage.removeItem(k);
      }
      i--;
    }
    return true;
  },

  remove(key) {
    if (!safeLocalStorage) { return; }
    return safeLocalStorage.removeItem(this.context + key);
  },

  set(opts) {
    if (!safeLocalStorage) { return false; }
    safeLocalStorage[this.context + opts.key] = opts.value;
  },

  get(key) {
    if (!safeLocalStorage) { return null; }
    return safeLocalStorage[this.context + key];
  },

  getInt(key, def) {
    if (!def) { def = 0; }
    if (!safeLocalStorage) { return def; }
    const result = parseInt(this.get(key));
    if (!isFinite(result)) { return def; }
    return result;
  },

  getObject(key) {
    if (!safeLocalStorage) { return null; }
    try {
      return JSON.parse(safeLocalStorage[this.context + key]);
    } catch(e) {}
  }
};

// API compatibility with `localStorage`
KeyValueStore.prototype.getItem = KeyValueStore.prototype.get;
KeyValueStore.prototype.removeItem = KeyValueStore.prototype.remove;
KeyValueStore.prototype.setItem = function(key, value) {
  this.set({ key, value });
};


export default KeyValueStore;
