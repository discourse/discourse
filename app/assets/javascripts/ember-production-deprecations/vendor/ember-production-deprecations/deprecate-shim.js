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

    const deprecate = require("@ember/debug").deprecate;

    // Patch ember-global deprecation
    ["Ember", "Em"].forEach((key) => {
      if (window.hasOwnProperty(key)) {
        Object.defineProperty(window, key, {
          enumerable: true,
          configurable: true,
          get() {
            deprecate(
              `Usage of the ${key} Global is deprecated. You should import the Ember module or the specific API instead.`,
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
      }
    });

    // Patch run.blah deprecations
    // https://github.com/emberjs/ember.js/blob/007fc9eba1/packages/%40ember/runloop/index.js#L748-L808
    const deprecatedRunloopFunctions = [
      "backburner",
      "begin",
      "bind",
      "cancel",
      "debounce",
      "end",
      "hasScheduledTimers",
      "join",
      "later",
      "next",
      "once",
      "schedule",
      "scheduleOnce",
      "throttle",
      "cancelTimers",
    ];

    const run = require("@ember/runloop").run;
    for (const name of deprecatedRunloopFunctions) {
      const currentDescriptor = Object.getOwnPropertyDescriptor(run, name);
      if (currentDescriptor?.value) {
        Object.defineProperty(run, name, {
          get() {
            deprecate(
              `Using \`run.${name}\` has been deprecated. Instead, import the value directly.`,
              false,
              {
                id: "deprecated-run-loop-and-computed-dot-access",
                until: "4.0.0",
                for: "ember-source",
                since: {
                  enabled: "3.27.0",
                },
                url: "https://deprecations.emberjs.com/v3.x/#toc_deprecated-run-loop-and-computed-dot-access",
              }
            );
            return currentDescriptor.value;
          },
        });
      }
    }

    // Patch computed.blah deprecations
    // https://github.com/emberjs/ember.js/blob/v3.28.12/packages/%40ember/object/index.js#L60-L118
    const deprecatedComputedFunctions = [
      "alias",
      "and",
      "bool",
      "collect",
      "deprecatingAlias",
      "empty",
      "equal",
      "filterBy",
      "filter",
      "gte",
      "gt",
      "intersect",
      "lte",
      "lt",
      "mapBy",
      "map",
      "match",
      "max",
      "min",
      "none",
      "notEmpty",
      "not",
      "oneWay",
      "reads",
      "or",
      "readOnly",
      "setDiff",
      "sort",
      "sum",
      "union",
      "uniqBy",
      "uniq",
    ];

    const computed = require("@ember/object").computed;
    for (const name of deprecatedComputedFunctions) {
      const currentDescriptor = Object.getOwnPropertyDescriptor(computed, name);
      if (currentDescriptor?.value) {
        Object.defineProperty(computed, name, {
          get() {
            deprecate(
              `Using \`computed.${name}\` has been deprecated. Instead, import the value directly.`,
              false,
              {
                id: "deprecated-run-loop-and-computed-dot-access",
                until: "4.0.0",
                for: "ember-source",
                since: {
                  enabled: "3.27.0",
                },
                url: "https://deprecations.emberjs.com/v3.x/#toc_deprecated-run-loop-and-computed-dot-access",
              }
            );
            return currentDescriptor.value;
          },
        });
      }
    }
  };
});

if (!require("@glimmer/env").DEBUG) {
  require("discourse/lib/deprecate-shim").applyShim();
}
