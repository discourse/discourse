const TapReporter = require("testem/lib/reporters/tap_reporter");
const fs = require("fs");
const displayUtils = require("testem/lib/utils/displayutils");
const colors = require("@colors/colors/safe");

class Reporter extends TapReporter {
  failReports = [];
  deprecationCounts = new Map();

  constructor() {
    super(...arguments);

    // Colors are enabled automatically in dev env, just need to toggle them on in GH
    if (process.env.GITHUB_ACTIONS) {
      colors.enable();
    }

    if (process.env.GITHUB_ACTIONS) {
      this.out.write("::group:: Verbose QUnit test output\n");
    }
  }

  reportMetadata(tag, metadata) {
    if (tag === "increment-deprecation") {
      const id = metadata.id;
      const currentCount = this.deprecationCounts.get(id) || 0;
      this.deprecationCounts.set(id, currentCount + 1);
    } else if (tag === "summary-line") {
      this.out.write(`\n${metadata.message}\n`);
    } else {
      super.reportMetadata(...arguments);
    }
  }

  report(prefix, data) {
    if (data.failed) {
      this.failReports.push([prefix, data, this.id]);
    }

    super.report(prefix, data);
  }

  display(prefix, result) {
    if (this.willDisplay(result)) {
      const string = displayUtils.resultString(
        this.id++,
        prefix,
        result,
        this.quietLogs,
        this.strictSpecCompliance
      );

      const color = this.colorForResult(result);
      const matches = string.match(/([\S\s]+?)(\n\s+browser\slog:[\S\s]+)/);

      if (matches) {
        this.out.write(color(matches[1]));
        this.out.write(colors.cyan(matches[2]));
      } else {
        this.out.write(color(string));
      }
    }
  }

  colorForResult(result) {
    if (result.todo || result.skipped) {
      return colors.yellow;
    } else if (result.passed) {
      return colors.green;
    } else {
      return colors.red;
    }
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
    this.out.write(`\n${deprecationMessage}\n\n`);
  }

  finish() {
    if (process.env.GITHUB_ACTIONS) {
      this.out.write("::endgroup::");
    }

    super.finish();

    this.reportDeprecations();

    if (this.failReports.length > 0) {
      this.out.write("\nFailures:\n\n");

      this.failReports.forEach(([prefix, data, id]) => {
        if (process.env.GITHUB_ACTIONS) {
          this.out.write(`::error ::QUnit Test Failure: ${data.name}\n`);
        }

        this.id = id;
        super.report(prefix, data);
      });
    }
  }
}

module.exports = {
  test_page: "tests/index.html?hidepassed",
  disable_watching: true,
  launch_in_ci: [process.env.TESTEM_DEFAULT_BROWSER || "Chrome"],
  tap_failed_tests_only: false,
  parallel: -1,
  browser_start_timeout: 120,
  browser_args: {
    Chromium: [
      // --no-sandbox is needed when running Chromium inside a container
      process.env.CI ? "--no-sandbox" : null,
      "--headless=new",
      "--disable-dev-shm-usage",
      "--disable-software-rasterizer",
      "--disable-search-engine-choice-screen",
      "--mute-audio",
      "--remote-debugging-port=4201",
      "--window-size=1440,900",
      "--enable-precise-memory-info",
      "--js-flags=--max_old_space_size=4096",
    ].filter(Boolean),
    Chrome: [
      // --no-sandbox is needed when running Chrome inside a container
      process.env.CI ? "--no-sandbox" : null,
      "--headless=new",
      "--disable-dev-shm-usage",
      "--disable-software-rasterizer",
      "--disable-search-engine-choice-screen",
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

fetch(`${target}/about.json`).catch(() => {
  // eslint-disable-next-line no-console
  console.error(
    colors.red(
      `Error connecting to Rails server on ${target}. Is it running? Use 'bin/rake qunit:test' or 'plugin:qunit' to start automatically.`
    )
  );
});

const themeTestPages = process.env.THEME_TEST_PAGES;

if (themeTestPages) {
  module.exports.test_page = themeTestPages.split(",");
  module.exports.proxies = {};

  // Prepend a prefix to the path of the route such that the server handling the request can easily identify `/theme-qunit`
  // requests. This is required because testem prepends a string to the path of the `test_page` option when it makes
  // the request and there is no easy way for us to strip the string from the path through the proxy. As such, we let the
  // destination server handle the request base on the prefix instead.
  module.exports.proxies[`/*/theme-qunit`] = {
    target: `${target}/testem-theme-qunit`,
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
} else {
  // Running with ember cli, but we want to pass through plugin request to Rails
  module.exports.proxies = {
    "/assets/plugins/*_extra.js": {
      target,
    },
    "/plugins/": {
      target,
    },
    "/bootstrap/": {
      target,
    },
    "/stylesheets/": {
      target,
    },
    "/extra-locales/": {
      target,
    },
  };
}
