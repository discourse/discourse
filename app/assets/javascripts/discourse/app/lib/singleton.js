/**
 * @decorator
 * Ensures only one instance of a class exists and provides global access to it.
 *
 * @example
 * ```
 * @singleton
 * class UserSettings {
 *   theme = 'light';
 *
 *   toggleTheme() {
 *     this.theme = this.theme === 'light' ? 'dark' : 'light';
 *   }
 * }
 *
 * // Get the singleton instance
 * const settings = UserSettings.current();
 *
 * // Access properties
 * UserSettings.currentProp('theme'); // 'light'
 * UserSettings.currentProp('theme', 'dark'); // sets and returns 'dark'
 *
 * // Multiple calls return the same instance
 * UserSettings.current() === UserSettings.current(); // true
 * ```
 */
export default function singleton(target) {
  return class SingletonClass extends target {
    static current() {
      if (!this._current) {
        this._current = this.createCurrent();
      }
      return this._current;
    }

    static createCurrent() {
      return this.create();
    }

    static currentProp(property, value) {
      const instance = this.current();
      if (!instance) {
        return;
      }

      if (typeof value !== "undefined") {
        instance[property] = value;
        return value;
      }
      return instance[property];
    }

    static resetCurrent(val) {
      this._current = val;
      return val;
    }

    static _current = null;
  };
}
