const TapReporter = require("testem/lib/reporters/tap_reporter");
const fs = require("fs");
const path = require("path");
const displayUtils = require("testem/lib/utils/displayutils");
const colors = require("@colors/colors/safe");
const { buildReport } = require("./lib/deprecation-report");

require("./patch-testem-output")();
require("./patch-testem-browser-watchdog")();

const SANDBOX_DISABLE_VALUES = ["1", "true"];
const sandboxDisabled =
  process.env.CI ||
  SANDBOX_DISABLE_VALUES.includes(
    (process.env.DISCOURSE_DISABLE_BROWSER_SANDBOX || "").toLowerCase()
  );

const REPO_ROOT = path.resolve(__dirname, "..", "..");

// Number of detailed rows included in the GitHub job summary. The full set
// always goes to the JSON report artifact.
const SUMMARY_DETAIL_LIMIT = 25;

/**
 * Label identifying which CI run group produced a report, so the artifacts of a
 * single workflow run stay distinguishable.
 *
 * @returns {string}
 */
function deprecationReportGroup() {
  const explicit = process.env.DEPRECATION_REPORT_GROUP;
  if (explicit) {
    return explicit.replace(/[^\w.-]+/g, "-");
  }

  if (process.env.THEME_TEST_PAGES) {
    return "frontend-themes";
  } else if (process.env.PLUGIN_TARGETS) {
    return "frontend-plugins";
  }

  return "frontend-core";
}

class Reporter extends TapReporter {
  failReports = [];
  deprecationCounts = new Map();
  deprecationCountsByOrigin = new Map();
  deprecationDetails = [];

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
      const { id, origin } = metadata;

      const currentCount = this.deprecationCounts.get(id) || 0;
      this.deprecationCounts.set(id, currentCount + 1);

      const originKey = origin || "unknown";
      if (!this.deprecationCountsByOrigin.has(originKey)) {
        this.deprecationCountsByOrigin.set(originKey, new Map());
      }
      const originMap = this.deprecationCountsByOrigin.get(originKey);
      const originCount = originMap.get(id) || 0;
      originMap.set(id, originCount + 1);
    } else if (tag === "deprecation-details") {
      this.deprecationDetails.push(...(metadata.details || []));
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
      this.showBrowserVersion(prefix);

      const rawString = displayUtils.resultString(
        this.id++,
        prefix,
        result,
        this.quietLogs,
        this.strictSpecCompliance
      );

      let string = this.reformatTapLine(rawString, prefix);

      const color = this.colorForResult(result);
      string = string.replace(/\n\s+---\n\s+browser\slog:[\S\s]+/, "\n");

      this.out.write(color(string));
    }
  }

  showBrowserVersion(prefix) {
    if (!prefix) {
      return;
    }

    this.shownBrowserVersions ??= new Set();
    if (!this.shownBrowserVersions.has(prefix)) {
      this.shownBrowserVersions.add(prefix);
      this.out.write(colors.gray(`# Launcher: ${prefix}\n`));
    }
  }

  reformatTapLine(rawString, prefix) {
    const newlineIndex = rawString.indexOf("\n");
    const firstLine =
      newlineIndex >= 0 ? rawString.slice(0, newlineIndex) : rawString;
    const rest = newlineIndex >= 0 ? rawString.slice(newlineIndex) : "";
    let line = firstLine;

    if (prefix) {
      const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      line = line.replace(
        new RegExp(
          `^(ok|not ok|skip|todo) (\\d+) ${escaped} - (\\[\\d+ ms\\])`
        ),
        "$1 $2 $3"
      );
    }

    line = line.replace(
      /^(ok|not ok|skip|todo) (\d+) (\[\d+ ms\]) - Browser Id (\d+) - /,
      "$1 $2 #$4 $3 - "
    );

    return line + rest;
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

    let msg = this.buildTableHeader(["id", "count"], [maxIdLength, 5]);

    for (const [id, count] of this.deprecationCounts.entries()) {
      const countString = count.toString();
      msg += `| ${id.padEnd(maxIdLength)} | ${countString.padStart(5)} |\n`;
    }

    return msg;
  }

  generateDeprecationsByOriginTable() {
    const allDeprecationIds = this.collectAllDeprecationIds();
    const maxIdLength = Math.max(
      ...Array.from(allDeprecationIds).map((id) => id.length)
    );
    const origins = Array.from(this.deprecationCountsByOrigin.keys()).sort();
    const maxOriginLength = Math.max(...origins.map((o) => o.length), 6);

    let msg = this.buildTableHeader(
      ["origin", "id", "count"],
      [maxOriginLength, maxIdLength, 5]
    );

    for (const origin of origins) {
      const originMap = this.deprecationCountsByOrigin.get(origin);
      const sortedIds = Array.from(originMap.keys()).sort();

      for (const id of sortedIds) {
        const count = originMap.get(id);
        const countString = count.toString();
        msg += `| ${origin.padEnd(maxOriginLength)} | ${id.padEnd(maxIdLength)} | ${countString.padStart(5)} |\n`;
      }
    }

    return msg;
  }

  collectAllDeprecationIds() {
    const allIds = new Set();
    for (const originMap of this.deprecationCountsByOrigin.values()) {
      for (const id of originMap.keys()) {
        allIds.add(id);
      }
    }
    return allIds;
  }

  buildTableHeader(columnNames, columnWidths) {
    let header = "| ";
    let separator = "| ";

    for (let i = 0; i < columnNames.length; i++) {
      const name = columnNames[i];
      const width = columnWidths[i];
      header += `${name.padEnd(width)} | `;
      separator += `${"".padEnd(width, "-")} | `;
    }

    return header + "\n" + separator + "\n";
  }

  reportDeprecations() {
    if (this.deprecationCounts.size === 0) {
      this.out.write("\n[Deprecation Counter] No deprecations logged\n\n");
      this.writeDeprecationReport();
      return;
    }

    const table = this.generateDeprecationTable();
    let deprecationMessage =
      "[Deprecation Counter] Test run completed with deprecations:\n\n" + table;

    let originTable = null;
    if (this.deprecationCountsByOrigin.size > 0) {
      originTable = this.generateDeprecationsByOriginTable();
      deprecationMessage += "\nDeprecations by test origin:\n\n" + originTable;
    }

    const report = this.writeDeprecationReport();

    if (report) {
      deprecationMessage += `\nDetailed report: ${report.path}\n`;
    }

    this.writeGitHubSummary(table, originTable, report);
    this.out.write(`\n${deprecationMessage}\n\n`);
  }

  /**
   * Writes the machine-readable report which pairs every deprecation with the
   * spec that triggered it and the source location it came from.
   *
   * @returns {?{path: string, document: Object}}
   */
  writeDeprecationReport() {
    if (this.deprecationDetails.length === 0) {
      return null;
    }

    const group = deprecationReportGroup();
    const dir =
      process.env.DEPRECATION_REPORT_DIR ||
      path.join(REPO_ROOT, "tmp", "deprecation-reports");

    let document;
    try {
      document = buildReport({ group, entries: this.deprecationDetails });
    } catch (error) {
      this.out.write(
        `\n[Deprecation Counter] Failed to build detailed report: ${error}\n`
      );
      return null;
    }

    fs.mkdirSync(dir, { recursive: true });

    const file = path.join(dir, `${group}-${process.pid}.json`);
    fs.writeFileSync(file, JSON.stringify(document, null, 2));

    return { path: path.relative(REPO_ROOT, file), document };
  }

  generateDeprecationDetailTable(document) {
    let table = "| id | call site | count | specs |\n";
    table += "| -- | --------- | ----- | ----- |\n";

    for (const site of document.sites.slice(0, SUMMARY_DETAIL_LIMIT)) {
      const location = `${site.file}:${site.line}`;
      table += `| ${site.id} | ${location} | ${site.count} | ${site.specCount} |\n`;
    }

    return table;
  }

  writeGitHubSummary(table, originTable, report) {
    if (!process.env.GITHUB_ACTIONS || !process.env.GITHUB_STEP_SUMMARY) {
      return;
    }

    let jobSummary =
      "### ⚠️ JS Deprecations\n\nTest run completed with deprecations:\n\n";
    jobSummary += table;

    if (originTable) {
      jobSummary += "\n\nDeprecations by test origin:\n\n" + originTable;
    }

    if (report) {
      jobSummary += `\n\nTop ${SUMMARY_DETAIL_LIMIT} deprecated call sites (full details in the \`deprecation-reports\` artifact):\n\n`;
      jobSummary += this.generateDeprecationDetailTable(report.document);
    }

    jobSummary += "\n\n";

    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, jobSummary);
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
  test_page: "tests?hidepassed",
  disable_watching: true,
  launch_in_ci: [process.env.TESTEM_DEFAULT_BROWSER || "Chrome"],
  tap_failed_tests_only: false,
  parallel: parseInt(process.env.QUNIT_PARALLEL || 1, 10),
  socket_server_options: {
    maxHttpBufferSize: 1e8, // 100MB
  },
  browser_start_timeout:
    process.env.QUNIT_BROWSER_WATCHDOG === "1"
      ? parseInt(process.env.QUNIT_BROWSER_START_TIMEOUT, 10)
      : 120,
  browser_disconnect_timeout: 30,
  chrome_stderr_info_only: true,
  browser_args: {
    Chromium: [
      // --no-sandbox is needed when running Chromium inside a container or when explicitly requested
      sandboxDisabled ? "--no-sandbox" : null,
      process.env.QUNIT_HEADLESS === "0" ? null : "--headless=new",
      "--disable-dev-shm-usage",
      "--disable-software-rasterizer",
      "--disable-search-engine-choice-screen",
      "--mute-audio",
      `--remote-debugging-port=${process.env.CI ? 0 : 3001}`,
      "--window-size=1440,900",
      "--enable-precise-memory-info",
      "--js-flags=--max_old_space_size=4096",
      "--disable-background-networking",
    ].filter(Boolean),
    Chrome: [
      // --no-sandbox is needed when running Chrome inside a container or when explicitly requested
      sandboxDisabled ? "--no-sandbox" : null,
      process.env.QUNIT_HEADLESS === "0" ? null : "--headless=new",
      "--disable-dev-shm-usage",
      "--disable-software-rasterizer",
      "--disable-search-engine-choice-screen",
      "--mute-audio",
      `--remote-debugging-port=${process.env.CI ? 0 : 3001}`,
      "--window-size=1440,900",
      "--enable-precise-memory-info",
      "--js-flags=--max_old_space_size=4096",
      "--disable-background-networking",
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
      `Error connecting to Rails server on ${target}. Is it running? Use 'bin/qunit --standalone' or 'plugin:qunit' to start automatically.`
    )
  );
});

const pluginTestPages = process.env.PLUGIN_TARGETS;
const themeTestPages = process.env.THEME_TEST_PAGES;
module.exports.proxies = {};

if (pluginTestPages) {
  module.exports.test_page = pluginTestPages.split(",").map((plugin) => {
    return `tests?hidepassed&target=${plugin}`;
  });
} else if (themeTestPages) {
  // avoid double-slash in paths
  module.exports.test_page = themeTestPages
    .split(",")
    .map((p) => p.replace(/^\//, ""));
}

module.exports.proxies["/*/*"] = { target, xfwd: true };
