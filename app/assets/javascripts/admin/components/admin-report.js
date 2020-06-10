import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { makeArray } from "discourse-common/lib/helpers";
import { alias, or, and, equal, notEmpty, not } from "@ember/object/computed";
import EmberObject, { computed, action } from "@ember/object";
import { next } from "@ember/runloop";
import Component from "@ember/component";
import ReportLoader from "discourse/lib/reports-loader";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import Report, { SCHEMA_VERSION } from "admin/models/report";
import { isPresent } from "@ember/utils";
import { isTesting } from "discourse-common/config/environment";

const TABLE_OPTIONS = {
  perPage: 8,
  total: true,
  limit: 20,
  formatNumbers: true
};

const CHART_OPTIONS = {};

function collapseWeekly(data, average) {
  let aggregate = [];
  let bucket, i;
  let offset = data.length % 7;
  for (i = offset; i < data.length; i++) {
    if (bucket && i % 7 === offset) {
      if (average) {
        bucket.y = parseFloat((bucket.y / 7.0).toFixed(2));
      }
      aggregate.push(bucket);
      bucket = null;
    }

    bucket = bucket || { x: data[i].x, y: 0 };
    bucket.y += data[i].y;
  }

  return aggregate;
}

export default Component.extend({
  classNameBindings: [
    "isVisible",
    "isEnabled",
    "isLoading",
    "dasherizedDataSourceName"
  ],
  classNames: ["admin-report"],
  isEnabled: true,
  disabledLabel: I18n.t("admin.dashboard.disabled"),
  isLoading: false,
  rateLimitationString: null,
  dataSourceName: null,
  report: null,
  model: null,
  reportOptions: null,
  forcedModes: null,
  showAllReportsLink: false,
  filters: null,
  showTrend: false,
  showHeader: true,
  showTitle: true,
  showFilteringUI: false,
  showDatesOptions: alias("model.dates_filtering"),
  showRefresh: or("showDatesOptions", "model.available_filters.length"),
  shouldDisplayTrend: and("showTrend", "model.prev_period"),
  isVisible: not("isHidden"),

  init() {
    this._super(...arguments);

    this._reports = [];
  },

  isHidden: computed("siteSettings.dashboard_hidden_reports", function() {
    return (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean)
      .includes(this.dataSourceName);
  }),

  startDate: computed("filters.startDate", function() {
    if (this.filters && isPresent(this.filters.startDate)) {
      return moment(this.filters.startDate, "YYYY-MM-DD");
    } else {
      return moment();
    }
  }),

  endDate: computed("filters.endDate", function() {
    if (this.filters && isPresent(this.filters.endDate)) {
      return moment(this.filters.endDate, "YYYY-MM-DD");
    } else {
      return moment();
    }
  }),

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.report) {
      this._renderReport(this.report, this.forcedModes, this.currentMode);
    } else if (this.dataSourceName) {
      this._fetchReport();
    }
  },

  showError: or("showTimeoutError", "showExceptionError", "showNotFoundError"),
  showNotFoundError: equal("model.error", "not_found"),
  showTimeoutError: equal("model.error", "timeout"),
  showExceptionError: equal("model.error", "exception"),

  hasData: notEmpty("model.data"),

  @discourseComputed("dataSourceName", "model.type")
  dasherizedDataSourceName(dataSourceName, type) {
    return (dataSourceName || type || "undefined").replace(/_/g, "-");
  },

  @discourseComputed("dataSourceName", "model.type")
  dataSource(dataSourceName, type) {
    dataSourceName = dataSourceName || type;
    return `/admin/reports/${dataSourceName}`;
  },

  @discourseComputed("displayedModes.length")
  showModes(displayedModesLength) {
    return displayedModesLength > 1;
  },

  @discourseComputed("currentMode", "model.modes", "forcedModes")
  displayedModes(currentMode, reportModes, forcedModes) {
    const modes = forcedModes ? forcedModes.split(",") : reportModes;

    return makeArray(modes).map(mode => {
      const base = `btn-default mode-btn ${mode}`;
      const cssClass = currentMode === mode ? `${base} is-current` : base;

      return {
        mode,
        cssClass,
        icon: mode === "table" ? "table" : "signal"
      };
    });
  },

  @discourseComputed("currentMode")
  modeComponent(currentMode) {
    return `admin-report-${currentMode.replace(/_/g, "-")}`;
  },

  @discourseComputed(
    "dataSourceName",
    "startDate",
    "endDate",
    "filters.customFilters"
  )
  reportKey(dataSourceName, startDate, endDate, customFilters) {
    if (!dataSourceName || !startDate || !endDate) return null;

    startDate = startDate.toISOString(true).split("T")[0];
    endDate = endDate.toISOString(true).split("T")[0];

    let reportKey = "reports:";
    reportKey += [
      dataSourceName,
      isTesting() ? "start" : startDate.replace(/-/g, ""),
      isTesting() ? "end" : endDate.replace(/-/g, ""),
      "[:prev_period]",
      this.get("reportOptions.table.limit"),
      // Convert all filter values to strings to ensure unique serialization
      customFilters
        ? JSON.stringify(customFilters, (k, v) => (k ? `${v}` : v))
        : null,
      SCHEMA_VERSION
    ]
      .filter(x => x)
      .map(x => x.toString())
      .join(":");

    return reportKey;
  },

  @action
  onChangeDateRange(range) {
    this.send("refreshReport", {
      startDate: range.from,
      endDate: range.to
    });
  },

  @action
  applyFilter(id, value) {
    let customFilters = this.get("filters.customFilters") || {};

    if (typeof value === "undefined") {
      delete customFilters[id];
    } else {
      customFilters[id] = value;
    }

    this.send("refreshReport", {
      filters: customFilters
    });
  },

  @action
  refreshReport(options = {}) {
    this.attrs.onRefresh({
      type: this.get("model.type"),
      startDate:
        typeof options.startDate === "undefined"
          ? this.startDate
          : options.startDate,
      endDate:
        typeof options.endDate === "undefined" ? this.endDate : options.endDate,
      filters:
        typeof options.filters === "undefined"
          ? this.get("filters.customFilters")
          : options.filters
    });
  },

  @action
  exportCsv() {
    const args = {
      name: this.get("model.type"),
      start_date: this.startDate.toISOString(true).split("T")[0],
      end_date: this.endDate.toISOString(true).split("T")[0]
    };

    const customFilters = this.get("filters.customFilters");
    if (customFilters) {
      Object.assign(args, customFilters);
    }

    exportEntity("report", args).then(outputExportResult);
  },

  @action
  changeMode(mode) {
    this.set("currentMode", mode);
  },

  _computeReport() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (!this._reports || !this._reports.length) {
      return;
    }

    // on a slow network _fetchReport could be called multiple times between
    // T and T+x, and all the ajax responses would occur after T+(x+y)
    // to avoid any inconsistencies we filter by period and make sure
    // the array contains only unique values
    let filteredReports = this._reports.uniqBy("report_key");
    let report;

    const sort = r => {
      if (r.length > 1) {
        return r.findBy("type", this.dataSourceName);
      } else {
        return r;
      }
    };

    if (!this.startDate || !this.endDate) {
      report = sort(filteredReports)[0];
    } else {
      report = sort(
        filteredReports.filter(r => r.report_key.includes(this.reportKey))
      )[0];

      if (!report) return;
    }

    if (report.error === "not_found") {
      this.set("showFilteringUI", false);
    }

    this._renderReport(report, this.forcedModes, this.currentMode);
  },

  _renderReport(report, forcedModes, currentMode) {
    const modes = forcedModes ? forcedModes.split(",") : report.modes;
    currentMode = currentMode || (modes ? modes[0] : null);

    this.setProperties({
      model: report,
      currentMode,
      options: this._buildOptions(currentMode)
    });
  },

  _fetchReport() {
    this._super(...arguments);

    this.setProperties({ isLoading: true, rateLimitationString: null });

    next(() => {
      let payload = this._buildPayload(["prev_period"]);

      const callback = response => {
        if (!this.element || this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("isLoading", false);

        if (response === 429) {
          this.set(
            "rateLimitationString",
            I18n.t("admin.dashboard.too_many_requests")
          );
        } else if (response === 500) {
          this.set("model.error", "exception");
        } else if (response) {
          this._reports.push(this._loadReport(response));
          this._computeReport();
        }
      };

      ReportLoader.enqueue(this.dataSourceName, payload.data, callback);
    });
  },

  _buildPayload(facets) {
    let payload = { data: { cache: true, facets } };

    if (this.startDate) {
      payload.data.start_date = moment(this.startDate)
        .toISOString(true)
        .split("T")[0];
    }

    if (this.endDate) {
      payload.data.end_date = moment(this.endDate)
        .toISOString(true)
        .split("T")[0];
    }

    if (this.get("reportOptions.table.limit")) {
      payload.data.limit = this.get("reportOptions.table.limit");
    }

    if (this.get("filters.customFilters")) {
      payload.data.filters = this.get("filters.customFilters");
    }

    return payload;
  },

  _buildOptions(mode) {
    if (mode === "table") {
      const tableOptions = JSON.parse(JSON.stringify(TABLE_OPTIONS));
      return EmberObject.create(
        Object.assign(tableOptions, this.get("reportOptions.table") || {})
      );
    } else {
      const chartOptions = JSON.parse(JSON.stringify(CHART_OPTIONS));
      return EmberObject.create(
        Object.assign(chartOptions, this.get("reportOptions.chart") || {})
      );
    }
  },

  _loadReport(jsonReport) {
    Report.fillMissingDates(jsonReport, { filledField: "chartData" });

    if (jsonReport.chartData && jsonReport.modes[0] === "stacked_chart") {
      jsonReport.chartData = jsonReport.chartData.map(chartData => {
        if (chartData.length > 40) {
          return {
            data: collapseWeekly(chartData.data),
            req: chartData.req,
            label: chartData.label,
            color: chartData.color
          };
        } else {
          return chartData;
        }
      });
    } else if (jsonReport.chartData && jsonReport.chartData.length > 40) {
      jsonReport.chartData = collapseWeekly(
        jsonReport.chartData,
        jsonReport.average
      );
    }

    if (jsonReport.prev_data) {
      Report.fillMissingDates(jsonReport, {
        filledField: "prevChartData",
        dataField: "prev_data",
        starDate: jsonReport.prev_startDate,
        endDate: jsonReport.prev_endDate
      });

      if (jsonReport.prevChartData && jsonReport.prevChartData.length > 40) {
        jsonReport.prevChartData = collapseWeekly(
          jsonReport.prevChartData,
          jsonReport.average
        );
      }
    }

    return Report.create(jsonReport);
  }
});
