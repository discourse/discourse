import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import EmberObject, { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import AdminReportChart from "discourse/admin/components/admin-report-chart";
import AdminReportCounters from "discourse/admin/components/admin-report-counters";
import AdminReportInlineTable from "discourse/admin/components/admin-report-inline-table";
import AdminReportLegacy from "discourse/admin/components/admin-report-legacy";
import AdminReportNew from "discourse/admin/components/admin-report-new";
import AdminReportRadar from "discourse/admin/components/admin-report-radar";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import AdminReportStackedLineChart from "discourse/admin/components/admin-report-stacked-line-chart";
import AdminReportStorageStats from "discourse/admin/components/admin-report-storage-stats";
import AdminReportTable from "discourse/admin/components/admin-report-table";
import ReportFilterBoolComponent from "discourse/admin/components/report-filters/bool";
import ReportFilterCategoryComponent from "discourse/admin/components/report-filters/category";
import ReportFilterGroupComponent from "discourse/admin/components/report-filters/group";
import ReportFilterListComponent from "discourse/admin/components/report-filters/list";
import { REPORT_MODES } from "discourse/admin/lib/constants";
import Report, {
  DAILY_LIMIT_DAYS,
  SCHEMA_VERSION,
} from "discourse/admin/models/report";
import { reportModeComponent } from "discourse/lib/admin-report-additional-modes";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import { makeArray } from "discourse/lib/helpers";
import ReportLoader from "discourse/lib/reports-loader";
import { i18n } from "discourse-i18n";

const TABLE_OPTIONS = {
  perPage: 8,
  total: true,
  limit: 20,
  formatNumbers: true,
};

const CHART_OPTIONS = {};

export default class AdminReport extends Component {
  @service siteSettings;

  @tracked isLoading = false;
  @tracked rateLimitationString = null;
  @tracked model = null;
  @tracked currentMode = this.args.filters?.mode;
  @tracked options = null;
  @tracked dateRangeFrom = null;
  @tracked dateRangeTo = null;

  showHeader = this.args.showHeader ?? true;
  showFilteringUI = this.args.showFilteringUI ?? false;
  showDescriptionInTooltip = this.args.showDescriptionInTooltip ?? true;
  _reports = [];

  constructor() {
    super(...arguments);
    this.fetchOrRender();
  }

  get startDate() {
    if (this.dateRangeFrom) {
      return moment(this.dateRangeFrom);
    }

    let startDate = moment();
    if (this.args.filters && isPresent(this.args.filters.startDate)) {
      startDate = moment(this.args.filters.startDate, "YYYY-MM-DD");
    }

    return startDate;
  }

  get endDate() {
    if (this.dateRangeTo) {
      return moment(this.dateRangeTo);
    }

    let endDate = moment();
    if (this.args.filters && isPresent(this.args.filters.endDate)) {
      endDate = moment(this.args.filters.endDate, "YYYY-MM-DD");
    }

    return endDate;
  }

  get reportClasses() {
    const builtReportClasses = ["is-enabled"];

    if (this.isHidden) {
      builtReportClasses.push("hidden");
    }

    if (!this.isHidden) {
      builtReportClasses.push("is-visible");
    }

    if (this.isLoading) {
      builtReportClasses.push("is-loading");
    }

    if (this.showDescriptionInTooltip) {
      builtReportClasses.push("description-in-tooltip");
    }

    builtReportClasses.push(this.dasherizedDataSourceName);

    return builtReportClasses.join(" ");
  }

  get showDatesOptions() {
    return this.model?.dates_filtering;
  }

  get showRefresh() {
    return this.showDatesOptions || this.model?.available_filters.length > 0;
  }

  get shouldDisplayTrend() {
    return this.args.showTrend && this.model?.prev_period;
  }

  get showError() {
    return (
      this.showTimeoutError || this.showExceptionError || this.showNotFoundError
    );
  }

  get showNotFoundError() {
    return this.model?.error === "not_found";
  }

  get showTimeoutError() {
    return this.model?.error === "timeout";
  }

  get showExceptionError() {
    return this.model?.error === "exception";
  }

  get hasData() {
    return isPresent(this.model?.data);
  }

  get disabledLabel() {
    return this.args.disabledLabel || i18n("admin.dashboard.disabled");
  }

  get isHidden() {
    return (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean)
      .includes(this.args.dataSourceName);
  }

  get dasherizedDataSourceName() {
    return (this.args.dataSourceName || this.model.type || "undefined").replace(
      /_/g,
      "-"
    );
  }

  get dataSource() {
    let dataSourceName = this.args.dataSourceName || this.model.type;
    return `/admin/reports/${dataSourceName}`;
  }

  get showModes() {
    return this.displayedModes.length > 1;
  }

  get isChartMode() {
    return (
      this.currentMode === REPORT_MODES.chart ||
      this.currentMode === REPORT_MODES.stacked_chart ||
      this.currentMode === REPORT_MODES.stacked_line_chart
    );
  }

  @action
  changeGrouping(grouping) {
    this.refreshReport({ chartGrouping: grouping });
  }

  get displayedModes() {
    const modes = this.args.forcedModes
      ? this.args.forcedModes.split(",")
      : this.model?.modes;

    return makeArray(modes).map((mode) => {
      const base = `btn-default mode-btn ${mode}`;
      const cssClass = this.currentMode === mode ? `${base} btn-primary` : base;

      return {
        mode,
        cssClass,
        icon: mode === REPORT_MODES.table ? "table" : "signal",
      };
    });
  }

  reportFilterComponent(filter) {
    switch (filter.type) {
      case "bool":
        return ReportFilterBoolComponent;
      case "category":
        return ReportFilterCategoryComponent;
      case "group":
        return ReportFilterGroupComponent;
      case "list":
        return ReportFilterListComponent;
    }
  }

  get modeComponent() {
    const reportMode = this.currentMode.replace(/-/g, "_");
    switch (reportMode) {
      case REPORT_MODES.table:
        return AdminReportTable;
      case REPORT_MODES.inline_table:
        return AdminReportInlineTable;
      case REPORT_MODES.chart:
        return AdminReportChart;
      case REPORT_MODES.stacked_chart:
        return AdminReportStackedChart;
      case REPORT_MODES.stacked_line_chart:
        return AdminReportStackedLineChart;
      case REPORT_MODES.counters:
        return AdminReportCounters;
      case REPORT_MODES.radar:
        return AdminReportRadar;
      case REPORT_MODES.storage_stats:
        return AdminReportStorageStats;
      default:
        if (reportModeComponent(reportMode)) {
          return reportModeComponent(reportMode);
        }

        return null;
    }
  }

  get reportKey() {
    if (!this.args.dataSourceName || !this.startDate || !this.endDate) {
      return null;
    }

    const formattedStartDate = this.startDate.toISOString(true).split("T")[0];
    const formattedEndDate = this.endDate.toISOString(true).split("T")[0];

    let reportKey = "reports:";
    reportKey += [
      this.args.dataSourceName,
      isTesting() ? "start" : formattedStartDate.replace(/-/g, ""),
      isTesting() ? "end" : formattedEndDate.replace(/-/g, ""),
      "[:prev_period]",
      this.args.reportOptions?.table?.limit,
      // Convert all filter values to strings to ensure unique serialization
      this.args.filters?.customFilters
        ? JSON.stringify(this.args.filters?.customFilters, (k, v) =>
            k ? `${v}` : v
          )
        : null,
      SCHEMA_VERSION,
    ]
      .filter((x) => x)
      .map((x) => x.toString())
      .join(":");

    return reportKey;
  }

  get chartGroupings() {
    const chartGrouping = this.options?.chartGrouping;
    const options = ["daily", "weekly", "monthly"];

    const dataLength = Array.isArray(this.model.chartData?.[0]?.data)
      ? this.model.chartData[0].data.length
      : this.model.chartData?.length || 0;

    return options.map((id) => {
      return {
        id,
        disabled: id === "daily" && dataLength >= DAILY_LIMIT_DAYS,
        label: `admin.dashboard.reports.${id}`,
        class: `chart-grouping ${chartGrouping === id ? "active" : "inactive"}`,
      };
    });
  }

  @action
  onChangeDateRange(range) {
    this.dateRangeFrom = range.from;
    this.dateRangeTo = range.to;
  }

  @action
  applyFilter(id, value) {
    let customFilters = this.args.filters?.customFilters || {};

    if (typeof value === "undefined") {
      delete customFilters[id];
    } else {
      customFilters[id] = value;
    }

    this.refreshReport({ filters: customFilters });
  }

  @action
  refreshReport(options = {}) {
    if (!this.args.onRefresh) {
      return;
    }

    this.args.onRefresh({
      type: this.model.type,
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
          ? this.args.filters?.customFilters
          : options.filters,
    });
  }

  @action
  exportCsv() {
    const args = {
      name: this.model.type,
      start_date: this.startDate.toISOString(true).split("T")[0],
      end_date: this.endDate.toISOString(true).split("T")[0],
    };

    const customFilters = this.args.filters?.customFilters;
    if (customFilters) {
      Object.assign(args, customFilters);
    }

    if (this.options?.hiddenLabels?.length) {
      args.hidden_labels = this.options.hiddenLabels.join(",");
    }

    exportEntity("report", args).then(outputExportResult);
  }

  @action
  onChangeMode(mode) {
    this.currentMode = mode;
    this.refreshReport({ chartGrouping: null });
  }

  @bind
  fetchOrRender() {
    if (this.args.dataSourceName) {
      this._fetchReport();
    }
  }

  @bind
  _computeReport() {
    if (!this._reports || !this._reports.length) {
      return;
    }

    // on a slow network _fetchReport could be called multiple times between
    // T and T+x, and all the ajax responses would occur after T+(x+y)
    // to avoid any inconsistencies we filter by period and make sure
    // the array contains only unique values
    let filteredReports = uniqueItemsFromArray(this._reports, "report_key");
    let foundReport;

    const sort = (report) => {
      if (report.length > 1) {
        return report.find((value) => value.type === this.args.dataSourceName);
      } else {
        return report;
      }
    };

    if (!this.startDate || !this.endDate) {
      foundReport = sort(filteredReports)[0];
    } else {
      const reportKey = this.reportKey;
      foundReport = sort(
        filteredReports.filter((report) =>
          report.report_key.includes(reportKey)
        )
      )[0];

      if (!foundReport) {
        return;
      }
    }

    if (foundReport.error === "not_found") {
      this.showFilteringUI = false;
    }

    this._renderReport(foundReport);
  }

  @bind
  _renderReport(report) {
    const modes = this.args.forcedModes?.split(",") || report.modes;
    const currentMode = this.currentMode || modes?.[0];

    this.model = report;
    this.currentMode = currentMode;
    this.options = this._buildOptions(currentMode, report);
  }

  @bind
  _fetchReport() {
    this.isLoading = true;
    this.rateLimitationString = null;

    next(() => {
      let payload = this._buildPayload(["prev_period"]);

      const callback = (response) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.isLoading = false;

        if (response === 429) {
          this.rateLimitationString = i18n("admin.dashboard.too_many_requests");
        } else if (response === 500) {
          this.model?.set("error", "exception");
        } else if (response) {
          this._reports.push(this._loadReport(response));
          this._computeReport();
        }
      };

      ReportLoader.enqueue(this.args.dataSourceName, payload.data, callback);
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

    if (this.args.reportOptions?.table?.limit) {
      payload.data.limit = this.args.reportOptions?.table?.limit;
    }

    if (this.args.filters?.customFilters) {
      payload.data.filters = this.args.filters?.customFilters;
    }

    return payload;
  }

  _buildOptions(mode, report) {
    if (mode === REPORT_MODES.table) {
      const tableOptions = JSON.parse(JSON.stringify(TABLE_OPTIONS));
      return EmberObject.create(
        Object.assign(tableOptions, this.args.reportOptions?.table || {})
      );
    } else if (mode === REPORT_MODES.chart) {
      const chartOptions = JSON.parse(JSON.stringify(CHART_OPTIONS));
      return EmberObject.create(
        Object.assign(chartOptions, this.args.reportOptions?.chart || {}, {
          chartGrouping:
            this.args.reportOptions?.chartGrouping ||
            report.default_group_by ||
            Report.groupingForDatapoints(report.chartData.length),
        })
      );
    } else if (mode === REPORT_MODES.stacked_chart) {
      const stackedChartOptions = this.args.reportOptions?.stackedChart || {};
      const firstSeriesData = report.chartData?.[0]?.data || [];
      return Object.assign(stackedChartOptions, {
        chartGrouping:
          this.args.reportOptions?.chartGrouping ||
          report.default_group_by ||
          Report.groupingForDatapoints(firstSeriesData.length),
      });
    }
  }

  _loadReport(jsonReport) {
    Report.fillMissingDates(jsonReport, { filledField: "chartData" });

    if (
      jsonReport.chartData &&
      jsonReport.modes[0] === REPORT_MODES.stacked_chart
    ) {
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

  <template>
    {{#if this.siteSettings.reporting_improvements}}
      <AdminReportNew @report={{this}} @filters={{@filters}} />
    {{else}}
      <AdminReportLegacy @report={{this}} @filters={{@filters}} />
    {{/if}}
  </template>
}
