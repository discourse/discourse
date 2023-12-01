// Ember's deprecation and registerDeprecationHandler APIs are stripped from production
// builds via the DEBUG flag. This file provides a minimal reimplementation of them
// to be used in production

define("discourse/lib/deprecate-shim", ["exports"], function (exports) {
  exports.applyShim = function () {
    let handler = () => {};
    require("@ember/debug/lib/deprecate").registerHandler = (fn) => {
      const next = handler;
      handler = (message, options) => fn(message, options, next);
    };

    require("@ember/debug").deprecate = (message, test, options) => {
      if (test) {
        return;
      }
      handler(message, options);
    };

    function formatMessage(message, options) {
      if (options && options.id) {
        message = message + ` [deprecation id: ${options.id}]`;
      }
      if (options && options.url) {
        message += ` See ${options.url} for more details.`;
      }
      return message;
    }

    require("@ember/debug").registerDeprecationHandler(
      function shimLogDeprecationToConsole(message, options) {
        var updatedMessage = formatMessage(message, options);
        console.warn(`DEPRECATION: ${updatedMessage}`);
      }
    );

    // Patch ember-global deprecation
    Object.defineProperty(window, "Ember", {
      enumerable: true,
      configurable: true,
      get() {
        require("@ember/debug").deprecate(
          "Usage of the Ember Global is deprecated. You should import the Ember module or the specific API instead.",
          false,
          {
            id: "ember-global",
            until: "4.0.0",
            url: "https://deprecations.emberjs.com/v3.x/#toc_ember-global",
            for: "ember-source",
            since: {
              enabled: "3.27.0",
            },
          }
        );

        return require("ember").default;
      },
    });
  };
});

if (!require("@glimmer/env").DEBUG) {
  require("discourse/lib/deprecate-shim").applyShim();
}
