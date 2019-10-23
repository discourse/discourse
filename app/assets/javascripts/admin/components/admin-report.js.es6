import Component from "@ember/component";
import ReportLoader from "discourse/lib/reports-loader";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import { isNumeric } from "discourse/lib/utilities";
import { SCHEMA_VERSION, default as Report } from "admin/models/report";
import computed from "ember-addons/ember-computed-decorators";

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
  classNameBindings: ["isEnabled", "isLoading", "dasherizedDataSourceName"],
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
  startDate: null,
  endDate: null,
  showTrend: false,
  showHeader: true,
  showTitle: true,
  showFilteringUI: false,
  showDatesOptions: Ember.computed.alias("model.dates_filtering"),
  showRefresh: Ember.computed.or(
    "showDatesOptions",
    "model.available_filters.length"
  ),
  shouldDisplayTrend: Ember.computed.and("showTrend", "model.prev_period"),

  init() {
    this._super(...arguments);

    this._reports = [];
  },

  startDate: Ember.computed.reads("filters.startDate"),
  endDate: Ember.computed.reads("filters.endDate"),

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.report) {
      this._renderReport(this.report, this.forcedModes, this.currentMode);
    } else if (this.dataSourceName) {
      this._fetchReport();
    }
  },

  showError: Ember.computed.or(
    "showTimeoutError",
    "showExceptionError",
    "showNotFoundError"
  ),
  showNotFoundError: Ember.computed.equal("model.error", "not_found"),
  showTimeoutError: Ember.computed.equal("model.error", "timeout"),
  showExceptionError: Ember.computed.equal("model.error", "exception"),

  hasData: Ember.computed.notEmpty("model.data"),

  @computed("dataSourceName", "model.type")
  dasherizedDataSourceName(dataSourceName, type) {
    return (dataSourceName || type || "undefined").replace(/_/g, "-");
  },

  @computed("dataSourceName", "model.type")
  dataSource(dataSourceName, type) {
    dataSourceName = dataSourceName || type;
    return `/admin/reports/${dataSourceName}`;
  },

  @computed("displayedModes.length")
  showModes(displayedModesLength) {
    return displayedModesLength > 1;
  },

  @computed("currentMode", "model.modes", "forcedModes")
  displayedModes(currentMode, reportModes, forcedModes) {
    const modes = forcedModes ? forcedModes.split(",") : reportModes;

    return Ember.makeArray(modes).map(mode => {
      const base = `btn-default mode-btn ${mode}`;
      const cssClass = currentMode === mode ? `${base} is-current` : base;

      return {
        mode,
        cssClass,
        icon: mode === "table" ? "table" : "signal"
      };
    });
  },

  @computed("currentMode")
  modeComponent(currentMode) {
    return `admin-report-${currentMode}`;
  },

  @computed("startDate")
  normalizedStartDate(startDate) {
    return startDate && typeof startDate.isValid === "function"
      ? moment
          .utc(startDate.toISOString())
          .locale("en")
          .format("YYYYMMDD")
      : moment(startDate)
          .locale("en")
          .format("YYYYMMDD");
  },

  @computed("endDate")
  normalizedEndDate(endDate) {
    return endDate && typeof endDate.isValid === "function"
      ? moment
          .utc(endDate.toISOString())
          .locale("en")
          .format("YYYYMMDD")
      : moment(endDate)
          .locale("en")
          .format("YYYYMMDD");
  },

  @computed(
    "dataSourceName",
    "normalizedStartDate",
    "normalizedEndDate",
    "filters.customFilters"
  )
  reportKey(dataSourceName, startDate, endDate, customFilters) {
    if (!dataSourceName || !startDate || !endDate) return null;

    let reportKey = "reports:";
    reportKey += [
      dataSourceName,
      Ember.testing ? "start" : startDate.replace(/-/g, ""),
      Ember.testing ? "end" : endDate.replace(/-/g, ""),
      "[:prev_period]",
      this.get("reportOptions.table.limit"),
      customFilters
        ? JSON.stringify(customFilters, (key, value) =>
            isNumeric(value) ? value.toString() : value
          )
        : null,
      SCHEMA_VERSION
    ]
      .filter(x => x)
      .map(x => x.toString())
      .join(":");

    return reportKey;
  },

  actions: {
    onChangeEndDate(date) {
      const startDate = moment(this.startDate);
      const newEndDate = moment(date).endOf("day");

      if (newEndDate.isSameOrAfter(startDate)) {
        this.set("endDate", newEndDate.format("YYYY-MM-DD"));
      } else {
        this.set("endDate", startDate.endOf("day").format("YYYY-MM-DD"));
      }

      this.send("refreshReport");
    },

    onChangeStartDate(date) {
      const endDate = moment(this.endDate);
      const newStartDate = moment(date).startOf("day");

      if (newStartDate.isSameOrBefore(endDate)) {
        this.set("startDate", newStartDate.format("YYYY-MM-DD"));
      } else {
        this.set("startDate", endDate.startOf("day").format("YYYY-MM-DD"));
      }

      this.send("refreshReport");
    },

    applyFilter(id, value) {
      let customFilters = this.get("filters.customFilters") || {};

      if (typeof value === "undefined") {
        delete customFilters[id];
      } else {
        customFilters[id] = value;
      }

      this.attrs.onRefresh({
        type: this.get("model.type"),
        startDate: this.startDate,
        endDate: this.endDate,
        filters: customFilters
      });
    },

    refreshReport() {
      this.attrs.onRefresh({
        type: this.get("model.type"),
        startDate: this.startDate,
        endDate: this.endDate,
        filters: this.get("filters.customFilters")
      });
    },

    exportCsv() {
      const customFilters = this.get("filters.customFilters") || {};

      exportEntity("report", {
        name: this.get("model.type"),
        start_date: this.startDate,
        end_date: this.endDate,
        category_id: customFilters.category,
        group_id: customFilters.group
      }).then(outputExportResult);
    },

    changeMode(mode) {
      this.set("currentMode", mode);
    }
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
      const reportKey = this.reportKey;

      report = sort(
        filteredReports.filter(r => r.report_key.includes(reportKey))
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

    Ember.run.next(() => {
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
      payload.data.start_date = moment
        .utc(this.startDate, "YYYY-MM-DD")
        .toISOString();
    }

    if (this.endDate) {
      payload.data.end_date = moment
        .utc(this.endDate, "YYYY-MM-DD")
        .toISOString();
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
      return Ember.Object.create(
        Object.assign(tableOptions, this.get("reportOptions.table") || {})
      );
    } else {
      const chartOptions = JSON.parse(JSON.stringify(CHART_OPTIONS));
      return Ember.Object.create(
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
