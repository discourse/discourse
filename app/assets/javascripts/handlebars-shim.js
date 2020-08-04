// allow us to import this as a module
if (typeof define !== "undefined") {
  define("handlebars", ["exports"], function(__exports__) {
    // It might not be defined server side, which is OK for pretty-text
    if (typeof Handlebars !== "undefined") {
      // eslint-disable-next-line
      __exports__.default = Handlebars;
    }
  });

  define("handlebars-compiler", ["exports"], function(__exports__) {
    // eslint-disable-next-line
    __exports__.default = Handlebars.compile;
  });
}
