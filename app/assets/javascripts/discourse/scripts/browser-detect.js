/* eslint-disable no-var */ // `let` is not supported in very old browsers

(function () {
  function check(name, passed) {
    if (!passed) {
      // eslint-disable-next-line no-console
      console.warn(name + " is not supported");
    }
    return passed;
  }
  if (
    !check("weakMap", window.WeakMap) ||
    !check("promise", window.Promise) ||
    !check("globalThis", typeof globalThis !== "undefined") ||
    !check("replaceAll", String.prototype.replaceAll) ||
    !check("supports", CSS.supports) ||
    !check("aspectRatio", CSS.supports("aspect-ratio: 1")) ||
    !check("relativeColor", CSS.supports("(color: hsl(from white h s l))")) ||
    !check("subgrid", CSS.supports("(grid-template-rows: subgrid)"))
  ) {
    window.unsupportedBrowser = true;
  } else {
    // Some implementations of `WeakMap.prototype.has` do not accept false
    // values and Ember's `isClassicDecorator` sometimes does that (it only
    // checks for `null` and `undefined`).
    try {
      new WeakMap().has(0);
      // eslint-disable-next-line no-unused-vars -- old browsers require binding this variable, even if unused
    } catch (err) {
      window.unsupportedBrowser = true;
    }

    var match = window.navigator.userAgent.match(/Firefox\/([0-9]+)\./);
    var firefoxVersion = match ? parseInt(match[1], 10) : null;
    if (firefoxVersion && firefoxVersion < 89) {
      // prior to v89, Firefox has bugs with document.execCommand("insertText")
      // https://bugzil.la/1220696
      window.unsupportedBrowser = true;
    }
  }
})();
