const TapReporter = require("testem/lib/reporters/tap_reporter");
const { shouldLoadPluginTestJs } = require("discourse/lib/plugin-js");

class Reporter {
  constructor() {
    this._tapReporter = new TapReporter(...arguments);
  }

  reportMetadata(tag, metadata) {
    if (tag === "summary-line") {
      process.stdout.write(`\n${metadata.message}\n`);
    } else {
      this._tapReporter.reportMetadata(...arguments);
    }
  }

  report(prefix, data) {
    this._tapReporter.report(prefix, data);
  }

  finish() {
    this._tapReporter.finish();
  }
}

module.exports = {
  test_page: "tests/index.html?hidepassed",
  disable_watching: true,
  launch_in_ci: ["Chrome"],
  // launch_in_dev: ["Chrome"] // Ember-CLI always launches testem in 'CI' mode
  tap_failed_tests_only: process.env.CI,
  parallel: 1, // disable parallel tests for stability
  browser_start_timeout: 120,
  browser_args: {
    Chrome: [
      // --no-sandbox is needed when running Chrome inside a container
      process.env.CI || process.env.EMBER_CLI ? "--no-sandbox" : null,
      "--headless",
      "--disable-dev-shm-usage",
      "--disable-software-rasterizer",
      "--mute-audio",
      "--remote-debugging-port=4201",
      "--window-size=1440,900",
      "--enable-precise-memory-info",
      "--js-flags=--max_old_space_size=4096",
    ].filter(Boolean),
    Firefox: ["-headless", "--width=1440", "--height=900"],
    "Headless Firefox": ["--width=1440", "--height=900"],
  },
  browser_paths: {
    "Headless Firefox": "/opt/firefox-evergreen/firefox",
  },
  reporter: Reporter,
};

if (shouldLoadPluginTestJs()) {
  const target = `http://localhost:${process.env.UNICORN_PORT || "3000"}`;
  module.exports.proxies = {
    "/assets/discourse/tests/active-plugins.js": {
      target,
    },
    "/assets/discourse/tests/plugin-tests.js": {
      target,
    },
  };
}
