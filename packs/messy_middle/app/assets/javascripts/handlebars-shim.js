// allow us to import this as a module
if (typeof define !== "undefined") {
  define("handlebars", ["exports"], function (__exports__) {
    // It might not be defined server side, which is OK for pretty-text
    if (typeof Handlebars !== "undefined") {
      // eslint-disable-next-line
      __exports__.default = Handlebars;
      __exports__.compile = function () {
        // eslint-disable-next-line
        return Handlebars.compile.apply(this, arguments);
      };
    }
  });

  define("handlebars-compiler", ["exports"], function (__exports__) {
    // eslint-disable-next-line
    __exports__.default = Handlebars.compile;
  });
}
