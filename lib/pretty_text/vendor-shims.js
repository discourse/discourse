define("@embroider/macros", ["exports", "require"], function (
  __require__,
  __exports__
) {
  __exports__.importSync = __require__;
});

define("discourse/lib/loader-shim", ["exports", "require"], function (
  __exports__,
  __require__
) {
  __exports__.default = (id, callback) => {
    if (!__require__.has(id)) {
      define(id, callback);
    }
  };
});

define("xss", ["exports"], function (__exports__) {
  __exports__.default = window.filterXSS;
});

define("markdown-it", ["exports"], function (exports) {
  exports.default = window.markdownit;
});
