"use strict";

// This is used only in the test environment!
// See app/helpers/application_helper.rb#discourse_config_environment
// for the method that generates configs for other envs.
module.exports = function (environment) {
  const ENV = {
    modulePrefix: "discourse",
    environment,
    rootURL: `${process.env.DISCOURSE_RELATIVE_URL_ROOT ?? ""}/`, // Add a trailing slash (not required by the Rails app in this env variable)
    locationType: "history",
    EmberENV: {
      FEATURES: {
        // Here you can enable experimental features on an ember canary build
        // e.g. EMBER_NATIVE_DECORATOR_SUPPORT: true
      },
      EXTEND_PROTOTYPES: {
        // Prevent Ember Data from overriding Date.parse.
        Date: false,
        String: false,
      },
      LOG_STACKTRACE_ON_DEPRECATION: false,
    },

    APP: {
      // Here you can pass flags/options to your application instance
      // when it is created
    },
  };

  if (process.env.EMBER_RAISE_ON_DEPRECATION === "1") {
    ENV.EmberENV.RAISE_ON_DEPRECATION = true;
  } else if (process.env.EMBER_RAISE_ON_DEPRECATION === "0") {
    ENV.EmberENV.RAISE_ON_DEPRECATION = false;
  } else {
    // Default (normally false; true in core qunit runs)
  }

  if (environment === "test") {
    // Testem prefers this...
    ENV.locationType = "none";

    // keep test console output quieter
    ENV.APP.LOG_ACTIVE_GENERATION = false;
    ENV.APP.LOG_VIEW_LOOKUPS = false;

    ENV.APP.rootElement = "#ember-testing";
    ENV.APP.autoboot = false;
  }

  return ENV;
};
