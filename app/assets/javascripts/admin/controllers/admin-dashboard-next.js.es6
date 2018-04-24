import DiscourseURL from "discourse/lib/url";
import computed from "ember-addons/ember-computed-decorators";
import AdminDashboardNext from 'admin/models/admin-dashboard-next';
import Report from 'admin/models/report';

const ATTRIBUTES = [ "disk_space", "updated_at", "last_backup_taken_at"];

const REPORTS = [ "global_reports", "user_reports" ];

export default Ember.Controller.extend({
  queryParams: ["period"],
  period: "all",
  isLoading: false,
  dashboardFetchedAt: null,
  exceptionController: Ember.inject.controller('exception'),

  fetchDashboard() {
    if (this.get("isLoading")) return;

    if (!this.get("dashboardFetchedAt") || moment().subtract(30, "minutes").toDate() > this.get("dashboardFetchedAt")) {
      this.set("isLoading", true);

      AdminDashboardNext.find().then(d => {
        this.set("dashboardFetchedAt", new Date());

        const reports = {};
        REPORTS.forEach(name => d[name].forEach(r => reports[`${name}_${r.type}`] = Report.create(r)));
        this.setProperties(reports);

        ATTRIBUTES.forEach(a => this.set(a, d[a]));
      }).catch(e => {
        this.get("exceptionController").set("thrown", e.jqXHR);
        this.replaceRoute("exception");
      }).finally(() => {
        this.set("isLoading", false);
      });
    }
  },

  @computed("period")
  startDate(period) {
    switch (period) {
      case "yearly":
        return moment().subtract(1, "year").startOf("day");
        break;
      case "quarterly":
        return moment().subtract(3, "month").startOf("day");
        break;
      case "weekly":
        return moment().subtract(1, "week").startOf("day");
        break;
      case "monthly":
        return moment().subtract(1, "month").startOf("day");
        break;
      case "daily":
        return moment().startOf("day");
        break;
      default:
        return null;
    }
  },

  @computed("period")
  endDate(period) {
    return period === "all" ? null : moment().endOf("day");
  },

  @computed("updated_at")
  updatedTimestamp(updatedAt) {
    return moment(updatedAt).format("LLL");
  },

  @computed("last_backup_taken_at")
  backupTimestamp(lastBackupTakenAt) {
    return moment(lastBackupTakenAt).format("LLL");
  },

  actions: {
    changePeriod(period) {
      DiscourseURL.routeTo(this._reportsForPeriodURL(period));
    }
  },

  _reportsForPeriodURL(period) {
    return `/admin/dashboard-next?period=${period}`;
  }
});
