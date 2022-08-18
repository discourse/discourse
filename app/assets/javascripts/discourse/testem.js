const TapReporter = require("testem/lib/reporters/tap_reporter");
const { shouldLoadPluginTestJs } = require("discourse/lib/plugin-js");

class Reporter {
  failReports = [];

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
    if (data.failed) {
      this.failReports.push([prefix, data]);
    }
    this._tapReporter.report(prefix, data);
  }

  finish() {
    this._tapReporter.finish();

    if (this.failReports.length > 0) {
      process.stdout.write("\nFailures:\n\n");
      this.failReports.forEach(([prefix, data]) => {
        if (process.env.GITHUB_ACTIONS) {
          process.stdout.write(`::error ::QUnit Test Failure: ${data.name}\n`);
        }
        this.report(prefix, data);
      });
    }
  }
}

module.exports = {
  test_page: "tests/index.html?hidepassed",
  disable_watching: true,
  launch_in_ci: ["Chrome"],
  // launch_in_dev: ["Chrome"] // Ember-CLI always launches testem in 'CI' mode
  tap_failed_tests_only: false,
  parallel: 1, // disable parallel tests for stability
  browser_start_timeout: 120,
  browser_args: {
    Chrome: [
      // --no-sandbox is needed when running Chrome inside a container
      process.env.CI ? "--no-sandbox" : null,
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

const target = `http://localhost:${process.env.UNICORN_PORT || "3000"}`;

if (process.argv.includes("-t")) {
  // Running testem without ember cli. Probably for theme-qunit
  const testPage = process.argv[process.argv.indexOf("-t") + 1];

  module.exports.proxies = {};
  module.exports.proxies[`/*/theme-qunit`] = {
    target: `${target}${testPage}`,
    ignorePath: true,
    xfwd: true,
  };
  module.exports.proxies["/*/*"] = { target, xfwd: true };

  module.exports.middleware = [
    function (app) {
      // Make the testem.js file available under /assets
      // so it's within the app's CSP
      app.get("/assets/testem.js", function (req, res, next) {
        req.url = "/testem.js";
        next();
      });
    },
  ];
} else if (shouldLoadPluginTestJs()) {
  // Running with ember cli, but we want to pass through plugin request to Rails
  module.exports.proxies = {
    "/assets/discourse/tests/active-plugins.js": {
      target,
    },
    "/assets/admin-plugins.js": {
      target,
    },
    "/assets/discourse/tests/plugin-tests.js": {
      target,
    },
    "/plugins/": {
      target,
    },
  };
}
