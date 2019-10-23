import Controller from "@ember/controller";
import { setting } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";
import AdminDashboard from "admin/models/admin-dashboard";
import Report from "admin/models/report";
import PeriodComputationMixin from "admin/mixins/period-computation";

function staticReport(reportType) {
  return Ember.computed("reports.[]", function() {
    return Ember.makeArray(this.reports).find(
      report => report.type === reportType
    );
  });
}

export default Controller.extend(PeriodComputationMixin, {
  isLoading: false,
  dashboardFetchedAt: null,
  exceptionController: Ember.inject.controller("exception"),
  logSearchQueriesEnabled: setting("log_search_queries"),
  basePath: Discourse.BaseUri,

  @computed("siteSettings.dashboard_general_tab_activity_metrics")
  activityMetrics(metrics) {
    return (metrics || "").split("|").filter(m => m);
  },

  @computed
  activityMetricsFilters() {
    return {
      startDate: this.lastMonth,
      endDate: this.today
    };
  },

  @computed
  topReferredTopicsOptions() {
    return {
      table: { total: false, limit: 8 }
    };
  },

  @computed
  topReferredTopicsFilters() {
    return {
      startDate: moment()
        .subtract(6, "days")
        .startOf("day"),
      endDate: this.today
    };
  },

  @computed
  trendingSearchFilters() {
    return {
      startDate: moment()
        .subtract(1, "month")
        .startOf("day"),
      endDate: this.today
    };
  },

  @computed
  trendingSearchOptions() {
    return {
      table: { total: false, limit: 8 }
    };
  },

  @computed
  trendingSearchDisabledLabel() {
    return I18n.t("admin.dashboard.reports.trending_search.disabled", {
      basePath: Discourse.BaseUri
    });
  },

  usersByTypeReport: staticReport("users_by_type"),
  usersByTrustLevelReport: staticReport("users_by_trust_level"),
  storageReport: staticReport("storage_report"),

  fetchDashboard() {
    if (this.isLoading) return;

    if (
      !this.dashboardFetchedAt ||
      moment()
        .subtract(30, "minutes")
        .toDate() > this.dashboardFetchedAt
    ) {
      this.set("isLoading", true);

      AdminDashboard.fetchGeneral()
        .then(adminDashboardModel => {
          this.setProperties({
            dashboardFetchedAt: new Date(),
            model: adminDashboardModel,
            reports: Ember.makeArray(adminDashboardModel.reports).map(x =>
              Report.create(x)
            )
          });
        })
        .catch(e => {
          this.exceptionController.set("thrown", e.jqXHR);
          this.replaceRoute("exception");
        })
        .finally(() => this.set("isLoading", false));
    }
  },

  @computed("startDate", "endDate")
  filters(startDate, endDate) {
    return { startDate, endDate };
  },

  _reportsForPeriodURL(period) {
    return Discourse.getURL(`/admin?period=${period}`);
  }
});
