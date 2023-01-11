"use strict";

module.exports = function (environment) {
  let ENV = {
    modulePrefix: "discourse",
    environment,
    rootURL: process.env.DISCOURSE_RELATIVE_URL_ROOT || "/",
    locationType: "history",
    historySupportMiddleware: false,
    EmberENV: {
      FEATURES: {
        // Here you can enable experimental features on an ember canary build
        // e.g. EMBER_NATIVE_DECORATOR_SUPPORT: true
      },
      EXTEND_PROTOTYPES: {
        // Prevent Ember Data from overriding Date.parse.
        Date: false,
      },
      // This is easier to toggle than the flag in ember-cli-deprecation-workflow.
      RAISE_ON_DEPRECATION: false,
    },
    exportApplicationGlobal: true,

    APP: {
      // Here you can pass flags/options to your application instance
      // when it is created
    },
  };

  if (environment === "development") {
    // ENV.APP.LOG_RESOLVER = true;
    // ENV.APP.LOG_ACTIVE_GENERATION = true;
    // ENV.APP.LOG_TRANSITIONS = true;
    // ENV.APP.LOG_TRANSITIONS_INTERNAL = true;
    // ENV.APP.LOG_VIEW_LOOKUPS = true;
    ENV.EmberENV.RAISE_ON_DEPRECATION = false;
  }

  if (environment === "test") {
    // Testem prefers this...
    ENV.locationType = "none";

    // keep test console output quieter
    ENV.APP.LOG_ACTIVE_GENERATION = false;
    ENV.APP.LOG_VIEW_LOOKUPS = false;

    ENV.APP.rootElement = "#ember-testing";
    ENV.APP.autoboot = false;

    ENV.EmberENV.RAISE_ON_DEPRECATION = false;
  }

  if (environment === "production") {
    // here you can enable a production-specific feature
  }

  return ENV;
};
