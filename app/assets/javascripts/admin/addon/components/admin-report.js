import Component from "@ember/component";
import EmberObject, { action, computed } from "@ember/object";
import { alias, and, equal, notEmpty, or } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { isPresent } from "@ember/utils";
import { classNameBindings, classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import { makeArray } from "discourse/lib/helpers";
import ReportLoader from "discourse/lib/reports-loader";
import { i18n } from "discourse-i18n";
import Report, { DAILY_LIMIT_DAYS, SCHEMA_VERSION } from "admin/models/report";

const TABLE_OPTIONS = {
  perPage: 8,
  total: true,
  limit: 20,
  formatNumbers: true,
};

const CHART_OPTIONS = {};

@classNameBindings(
  "isHidden:hidden",
  "isHidden::is-visible",
  "isEnabled",
  "isLoading",
  "dasherizedDataSourceName"
)
@classNames("admin-report")
export default class AdminReport extends Component {
  isEnabled = true;
  disabledLabel = i18n("admin.dashboard.disabled");
  isLoading = false;
  rateLimitationString = null;
  dataSourceName = null;
  report = null;
  model = null;
  reportOptions = null;
  forcedModes = null;
  showAllReportsLink = false;
  filters = null;
  showTrend = false;
  showHeader = true;
  showTitle = true;
  showFilteringUI = false;

  @alias("model.dates_filtering") showDatesOptions;

  @or("showDatesOptions", "model.available_filters.length") showRefresh;

  @and("showTrend", "model.prev_period") shouldDisplayTrend;

  endDate = null;
  startDate = null;

  @or("showTimeoutError", "showExceptionError", "showNotFoundError") showError;
  @equal("model.error", "not_found") showNotFoundError;
  @equal("model.error", "timeout") showTimeoutError;
  @equal("model.error", "exception") showExceptionError;
  @notEmpty("model.data") hasData;

  _reports = [];

  @computed("siteSettings.dashboard_hidden_reports")
  get isHidden() {
    return (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean)
      .includes(this.dataSourceName);
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    let startDate = moment();
    if (this.filters && isPresent(this.filters.startDate)) {
      startDate = moment(this.filters.startDate, "YYYY-MM-DD");
    }
    this.set("startDate", startDate);

    let endDate = moment();
    if (this.filters && isPresent(this.filters.endDate)) {
      endDate = moment(this.filters.endDate, "YYYY-MM-DD");
    }
    this.set("endDate", endDate);

    if (this.filters) {
      this.set("currentMode", this.filters.mode);
    }

    if (this.report) {
      this._renderReport(this.report, this.forcedModes, this.currentMode);
    } else if (this.dataSourceName) {
      this._fetchReport();
    }
  }

  @discourseComputed("dataSourceName", "model.type")
  dasherizedDataSourceName(dataSourceName, type) {
    return (dataSourceName || type || "undefined").replace(/_/g, "-");
  }

  @discourseComputed("dataSourceName", "model.type")
  dataSource(dataSourceName, type) {
    dataSourceName = dataSourceName || type;
    return `/admin/reports/${dataSourceName}`;
  }

  @discourseComputed("displayedModes.length")
  showModes(displayedModesLength) {
    return displayedModesLength > 1;
  }

  @discourseComputed("currentMode")
  isChartMode(currentMode) {
    return currentMode === "chart";
  }

  @action
  changeGrouping(grouping) {
    this.send("refreshReport", {
      chartGrouping: grouping,
    });
  }

  @discourseComputed("currentMode", "model.modes", "forcedModes")
  displayedModes(currentMode, reportModes, forcedModes) {
    const modes = forcedModes ? forcedModes.split(",") : reportModes;

    return makeArray(modes).map((mode) => {
      const base = `btn-default mode-btn ${mode}`;
      const cssClass = currentMode === mode ? `${base} btn-primary` : base;

      return {
        mode,
        cssClass,
        icon: mode === "table" ? "table" : "signal",
      };
    });
  }

  @discourseComputed("currentMode")
  modeComponent(currentMode) {
    return `admin-report-${currentMode.replace(/_/g, "-")}`;
  }

  @discourseComputed(
    "dataSourceName",
    "startDate",
    "endDate",
    "filters.customFilters"
  )
  reportKey(dataSourceName, startDate, endDate, customFilters) {
    if (!dataSourceName || !startDate || !endDate) {
      return null;
    }

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
      SCHEMA_VERSION,
    ]
      .filter((x) => x)
      .map((x) => x.toString())
      .join(":");

    return reportKey;
  }

  @discourseComputed("options.chartGrouping", "model.chartData.length")
  chartGroupings(grouping, count) {
    const options = ["daily", "weekly", "monthly"];

    return options.map((id) => {
      return {
        id,
        disabled: id === "daily" && count >= DAILY_LIMIT_DAYS,
        label: `admin.dashboard.reports.${id}`,
        class: `chart-grouping ${grouping === id ? "active" : "inactive"}`,
      };
    });
  }

  @action
  onChangeDateRange(range) {
    this.setProperties({
      startDate: range.from,
      endDate: range.to,
    });
  }

  @action
  applyFilter(id, value) {
    let customFilters = this.get("filters.customFilters") || {};

    if (typeof value === "undefined") {
      delete customFilters[id];
    } else {
      customFilters[id] = value;
    }

    this.send("refreshReport", {
      filters: customFilters,
    });
  }

  @action
  refreshReport(options = {}) {
    if (!this.onRefresh) {
      return;
    }

    this.onRefresh({
      type: this.get("model.type"),
      mode: this.currentMode,
      chartGrouping: options.chartGrouping,
      startDate:
        typeof options.startDate === "undefined"
          ? this.startDate
          : options.startDate,
      endDate:
        typeof options.endDate === "undefined" ? this.endDate : options.endDate,
      filters:
        typeof options.filters === "undefined"
          ? this.get("filters.customFilters")
          : options.filters,
    });
  }

  @action
  exportCsv() {
    const args = {
      name: this.get("model.type"),
      start_date: this.startDate.toISOString(true).split("T")[0],
      end_date: this.endDate.toISOString(true).split("T")[0],
    };

    const customFilters = this.get("filters.customFilters");
    if (customFilters) {
      Object.assign(args, customFilters);
    }

    exportEntity("report", args).then(outputExportResult);
  }

  @action
  onChangeMode(mode) {
    this.set("currentMode", mode);

    this.send("refreshReport", {
      chartGrouping: null,
    });
  }

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

    const sort = (r) => {
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
        filteredReports.filter((r) => r.report_key.includes(this.reportKey))
      )[0];

      if (!report) {
        return;
      }
    }

    if (report.error === "not_found") {
      this.set("showFilteringUI", false);
    }

    this._renderReport(report, this.forcedModes, this.currentMode);
  }

  _renderReport(report, forcedModes, currentMode) {
    const modes = forcedModes ? forcedModes.split(",") : report.modes;
    currentMode = currentMode || (modes ? modes[0] : null);

    this.setProperties({
      model: report,
      currentMode,
      options: this._buildOptions(currentMode, report),
    });
  }

  _fetchReport() {
    this.setProperties({ isLoading: true, rateLimitationString: null });

    next(() => {
      let payload = this._buildPayload(["prev_period"]);

      const callback = (response) => {
        if (!this.element || this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("isLoading", false);

        if (response === 429) {
          this.set(
            "rateLimitationString",
            i18n("admin.dashboard.too_many_requests")
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
  }

  _buildPayload(facets) {
    let payload = { data: { facets } };

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
  }

  _buildOptions(mode, report) {
    if (mode === "table") {
      const tableOptions = JSON.parse(JSON.stringify(TABLE_OPTIONS));
      return EmberObject.create(
        Object.assign(tableOptions, this.get("reportOptions.table") || {})
      );
    } else if (mode === "chart") {
      const chartOptions = JSON.parse(JSON.stringify(CHART_OPTIONS));
      return EmberObject.create(
        Object.assign(chartOptions, this.get("reportOptions.chart") || {}, {
          chartGrouping:
            this.get("reportOptions.chartGrouping") ||
            Report.groupingForDatapoints(report.chartData.length),
        })
      );
    } else if (mode === "stacked-chart" || mode === "stacked_chart") {
      return this.get("reportOptions.stackedChart") || {};
    }
  }

  _loadReport(jsonReport) {
    Report.fillMissingDates(jsonReport, { filledField: "chartData" });

    if (jsonReport.chartData && jsonReport.modes[0] === "stacked_chart") {
      jsonReport.chartData = jsonReport.chartData.map((chartData) => {
        if (chartData.length > 40) {
          return {
            data: chartData.data,
            req: chartData.req,
            label: chartData.label,
            color: chartData.color,
          };
        } else {
          return chartData;
        }
      });
    }

    if (jsonReport.prev_data) {
      Report.fillMissingDates(jsonReport, {
        filledField: "prevChartData",
        dataField: "prev_data",
        starDate: jsonReport.prev_startDate,
        endDate: jsonReport.prev_endDate,
      });
    }

    return Report.create(jsonReport);
  }
}
