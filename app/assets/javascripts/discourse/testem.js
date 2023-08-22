const TapReporter = require("testem/lib/reporters/tap_reporter");
const { shouldLoadPlugins } = require("discourse-plugins");
const fs = require("fs");

class Reporter {
  failReports = [];
  deprecationCounts = new Map();

  constructor() {
    this._tapReporter = new TapReporter(...arguments);
  }

  reportMetadata(tag, metadata) {
    if (tag === "increment-deprecation") {
      const id = metadata.id;
      const currentCount = this.deprecationCounts.get(id) || 0;
      this.deprecationCounts.set(id, currentCount + 1);
    } else if (tag === "summary-line") {
      process.stdout.write(`\n${metadata.message}\n`);
    } else {
      this._tapReporter.reportMetadata(...arguments);
    }
  }

  report(prefix, data) {
    if (data.failed) {
      this.failReports.push([prefix, data, this._tapReporter.id]);
    }
    this._tapReporter.report(prefix, data);
  }

  generateDeprecationTable() {
    const maxIdLength = Math.max(
      ...Array.from(this.deprecationCounts.keys()).map((k) => k.length)
    );

    let msg = `| ${"id".padEnd(maxIdLength)} | count |\n`;
    msg += `| ${"".padEnd(maxIdLength, "-")} | ----- |\n`;

    for (const [id, count] of this.deprecationCounts.entries()) {
      const countString = count.toString();
      msg += `| ${id.padEnd(maxIdLength)} | ${countString.padStart(5)} |\n`;
    }

    return msg;
  }

  reportDeprecations() {
    let deprecationMessage = "[Deprecation Counter] ";
    if (this.deprecationCounts.size > 0) {
      const table = this.generateDeprecationTable();
      deprecationMessage += `Test run completed with deprecations:\n\n${table}`;

      if (process.env.GITHUB_ACTIONS && process.env.GITHUB_STEP_SUMMARY) {
        let jobSummary = `### ⚠️ JS Deprecations\n\nTest run completed with deprecations:\n\n`;
        jobSummary += table;
        jobSummary += `\n\n`;

        fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, jobSummary);
      }
    } else {
      deprecationMessage += "No deprecations logged";
    }
    process.stdout.write(`\n${deprecationMessage}\n\n`);
  }

  finish() {
    this._tapReporter.finish();

    this.reportDeprecations();

    if (this.failReports.length > 0) {
      process.stdout.write("\nFailures:\n\n");

      this.failReports.forEach(([prefix, data, id]) => {
        if (process.env.GITHUB_ACTIONS) {
          process.stdout.write(`::error ::QUnit Test Failure: ${data.name}\n`);
        }

        this._tapReporter.id = id;
        this._tapReporter.report(prefix, data);
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
  parallel: -1,
  browser_start_timeout: 120,
  browser_args: {
    Chrome: [
      // --no-sandbox is needed when running Chrome inside a container
      process.env.CI ? "--no-sandbox" : null,
      "--headless=new",
      "--disable-dev-shm-usage",
      "--disable-software-rasterizer",
      "--mute-audio",
      "--remote-debugging-port=4201",
      "--window-size=1440,900",
      "--enable-precise-memory-info",
      "--js-flags=--max_old_space_size=4096",
    ].filter(Boolean),
    Firefox: ["-headless", "--width=1440", "--height=900"],
  },
  reporter: Reporter,
};

if (process.env.TESTEM_FIREFOX_PATH) {
  module.exports.browser_paths ||= {};
  module.exports.browser_paths["Firefox"] = process.env.TESTEM_FIREFOX_PATH;
}

const target = `http://127.0.0.1:${process.env.UNICORN_PORT || "3000"}`;

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
} else if (shouldLoadPlugins()) {
  // Running with ember cli, but we want to pass through plugin request to Rails
  module.exports.proxies = {
    "/assets/plugins/*_extra.js": {
      target,
    },
    "/plugins/": {
      target,
    },
    "/bootstrap/plugin-css-for-tests.css": {
      target,
    },
    "/stylesheets/": {
      target,
    },
  };
}
