import { setting } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";
import AdminDashboardNext from "admin/models/admin-dashboard-next";
import Report from "admin/models/report";
import PeriodComputationMixin from "admin/mixins/period-computation";

function staticReport(reportType) {
  return function() {
    return Ember.makeArray(this.get("reports")).find(
      report => report.type === reportType
    );
  }.property("reports.[]");
}

export default Ember.Controller.extend(PeriodComputationMixin, {
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
      startDate: this.get("lastMonth"),
      endDate: this.get("today")
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
      endDate: this.get("today")
    };
  },

  @computed
  trendingSearchFilters() {
    return {
      startDate: moment()
        .subtract(1, "month")
        .startOf("day"),
      endDate: this.get("today")
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
    if (this.get("isLoading")) return;

    if (
      !this.get("dashboardFetchedAt") ||
      moment()
        .subtract(30, "minutes")
        .toDate() > this.get("dashboardFetchedAt")
    ) {
      this.set("isLoading", true);

      AdminDashboardNext.fetchGeneral()
        .then(adminDashboardNextModel => {
          this.setProperties({
            dashboardFetchedAt: new Date(),
            model: adminDashboardNextModel,
            reports: Ember.makeArray(adminDashboardNextModel.reports).map(x =>
              Report.create(x)
            )
          });
        })
        .catch(e => {
          this.get("exceptionController").set("thrown", e.jqXHR);
          this.replaceRoute("exception");
        })
        .finally(() => this.set("isLoading", false));
    }
  },

  @computed("startDate", "endDate")
  filters(startDate, endDate) {
    return { startDate, endDate };
  },

  @computed("model.attributes.updated_at")
  updatedTimestamp(updatedAt) {
    return moment(updatedAt)
      .tz(moment.tz.guess())
      .format("LLL");
  },

  _reportsForPeriodURL(period) {
    return Discourse.getURL(`/admin?period=${period}`);
  }
});
