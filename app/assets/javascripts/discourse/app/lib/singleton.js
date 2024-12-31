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
 *
 * // If you want to customize what logic is executed during creation of the singleton, redefine the `createCurrent` method:
 * @singleton
 * class UserSettings {
 *   theme = 'light';
 *
 *   toggleTheme() {
 *     this.theme = this.theme === 'light' ? 'dark' : 'light';
 *   }
 *
 *   static createCurrent() {
 *     return this.create({ font: 'Comic-Sans' });
 *   }
 * }
 *
 * UserSettings.currentProp('font'); // 'Comic-Sans'
 * ```
 */
export default function singleton(targetKlass) {
  targetKlass._current = null;

  // check ensures that we don't overwrite a customized createCurrent
  if (!targetKlass.createCurrent) {
    targetKlass.createCurrent = function () {
      return this.create();
    };
  }

  targetKlass.current = function () {
    if (!this._current) {
      this._current = this.createCurrent();
    }
    return this._current;
  };

  targetKlass.currentProp = function (property, value) {
    const instance = this.current();
    if (!instance) {
      return;
    }

    if (typeof value !== "undefined") {
      instance[property] = value;
      return value;
    }
    return instance[property];
  };

  targetKlass.resetCurrent = function (val) {
    this._current = val;
    return val;
  };

  return targetKlass;
}
