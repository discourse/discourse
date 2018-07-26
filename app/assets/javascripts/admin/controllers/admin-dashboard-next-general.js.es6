import { setting } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";
import AdminDashboardNext from "admin/models/admin-dashboard-next";
import Report from "admin/models/report";
import PeriodComputationMixin from "admin/mixins/period-computation";

const ACTIVITY_METRICS_REPORTS = [
  "page_view_total_reqs",
  "visits",
  "time_to_first_response",
  "likes",
  "flags",
  "user_to_user_private_messages_with_replies"
];

function staticReport(reportType) {
  return function() {
    return this.get("reports").find(x => x.type === reportType);
  }.property("reports.[]");
}

export default Ember.Controller.extend(PeriodComputationMixin, {
  isLoading: false,
  dashboardFetchedAt: null,
  exceptionController: Ember.inject.controller("exception"),
  diskSpace: Ember.computed.alias("model.attributes.disk_space"),
  logSearchQueriesEnabled: setting("log_search_queries"),
  lastBackupTakenAt: Ember.computed.alias(
    "model.attributes.last_backup_taken_at"
  ),
  shouldDisplayDurability: Ember.computed.and("diskSpace"),

  @computed
  topReferredTopicsTopions() {
    return { table: { total: false, limit: 8 } };
  },

  @computed
  trendingSearchOptions() {
    return { table: { total: false, limit: 8 } };
  },

  usersByTypeReport: staticReport("users_by_type"),
  usersByTrustLevelReport: staticReport("users_by_trust_level"),

  @computed("reports.[]")
  activityMetricsReports(reports) {
    return reports.filter(report =>
      ACTIVITY_METRICS_REPORTS.includes(report.type)
    );
  },

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
            reports: adminDashboardNextModel.reports.map(x => Report.create(x))
          });
        })
        .catch(e => {
          this.get("exceptionController").set("thrown", e.jqXHR);
          this.replaceRoute("exception");
        })
        .finally(() => this.set("isLoading", false));
    }
  },

  @computed("model.attributes.updated_at")
  updatedTimestamp(updatedAt) {
    return moment(updatedAt).format("LLL");
  },

  @computed("lastBackupTakenAt")
  backupTimestamp(lastBackupTakenAt) {
    return moment(lastBackupTakenAt).format("LLL");
  },

  _reportsForPeriodURL(period) {
    return Discourse.getURL(`/admin/dashboard/general?period=${period}`);
  }
});
