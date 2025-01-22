const SILENCED_WARN_PREFIXES = [
  "Setting the `jquery-integration` optional feature flag",
  'unexpectedly found "', // https://github.com/emberjs/ember.js/issues/19392
];

class DeprecationSilencer {
  constructor() {
    this.silenced = new WeakMap();
  }

  silence(object, method) {
    if (this.alreadySilenced(object, method)) {
      return;
    }

    let original = object[method];

    object[method] = (message, ...args) => {
      if (!this.shouldSilence(message)) {
        return original.call(object, message, ...args);
      }
    };
  }

  alreadySilenced(object, method) {
    let set = this.silenced.get(object);

    if (!set) {
      set = new Set();
      this.silenced.set(object, set);
    }

    if (set.has(method)) {
      return true;
    } else {
      set.add(method);
      return false;
    }
  }

  shouldSilence(message) {
    return SILENCED_WARN_PREFIXES.some((prefix) => message.startsWith(prefix));
  }
}

const DEPRECATION_SILENCER = new DeprecationSilencer();

/**
 * Export a dummy babel plugin which applies the console.warn silences in worker
 * processes. Does not actually affect babel output.
 */
module.exports = function () {
  DEPRECATION_SILENCER.silence(console, "warn");
  return {};
};

module.exports.silence = function silence(...args) {
  DEPRECATION_SILENCER.silence(...args);
};
