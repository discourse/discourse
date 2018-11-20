export default class DirtyKeys {
  constructor(name) {
    this.name = name;
    this._keys = {};
  }

  keyDirty(key, options) {
    options = options || {};
    options.dirty = true;
    this._keys[key] = options;
  }

  forceAll() {
    this.keyDirty("*");
  }

  allDirty() {
    return !!this._keys["*"];
  }

  optionsFor(key) {
    return this._keys[key] || { dirty: false };
  }

  renderedKey(key) {
    if (key === "*") {
      this._keys = {};
    } else {
      delete this._keys[key];
    }
  }
}
