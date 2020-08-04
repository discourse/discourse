if (!window.WeakMap || !window.Promise) {
  window.unsupportedBrowser = true;
} else {
  // Some implementations of `WeakMap.prototype.has` do not accept false
  // values and Ember's `isClassicDecorator` sometimes does that (it only
  // checks for `null` and `undefined`).
  try {
    new WeakMap().has(0);
  } catch (err) {
    window.unsupportedBrowser = true;
  }
}
