import { setting } from "discourse/lib/computed";
import DiscourseURL from "discourse/lib/url";
import computed from "ember-addons/ember-computed-decorators";
import AdminDashboardNext from "admin/models/admin-dashboard-next";
import Report from "admin/models/report";
import VersionCheck from "admin/models/version-check";

const PROBLEMS_CHECK_MINUTES = 1;

export default Ember.Controller.extend({
  queryParams: ["period"],
  period: "monthly",
  isLoading: false,
  dashboardFetchedAt: null,
  exceptionController: Ember.inject.controller("exception"),
  showVersionChecks: setting("version_checks"),
  diskSpace: Ember.computed.alias("model.attributes.disk_space"),
  lastBackupTakenAt: Ember.computed.alias(
    "model.attributes.last_backup_taken_at"
  ),
  logSearchQueriesEnabled: setting("log_search_queries"),
  availablePeriods: ["yearly", "quarterly", "monthly", "weekly"],
  shouldDisplayDurability: Ember.computed.and("lastBackupTakenAt", "diskSpace"),

  @computed("problems.length")
  foundProblems(problemsLength) {
    return this.currentUser.get("admin") && (problemsLength || 0) > 0;
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

      const versionChecks = this.siteSettings.version_checks;

      AdminDashboardNext.find()
        .then(adminDashboardNextModel => {
          if (versionChecks) {
            this.set(
              "versionCheck",
              VersionCheck.create(adminDashboardNextModel.version_check)
            );
          }

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
        .finally(() => {
          this.set("isLoading", false);
        });
    }

    if (
      !this.get("problemsFetchedAt") ||
      moment()
        .subtract(PROBLEMS_CHECK_MINUTES, "minutes")
        .toDate() > this.get("problemsFetchedAt")
    ) {
      this.loadProblems();
    }
  },

  loadProblems() {
    this.set("loadingProblems", true);
    this.set("problemsFetchedAt", new Date());
    AdminDashboardNext.fetchProblems()
      .then(d => {
        this.set("problems", d.problems);
      })
      .finally(() => {
        this.set("loadingProblems", false);
      });
  },

  @computed("problemsFetchedAt")
  problemsTimestamp(problemsFetchedAt) {
    return moment(problemsFetchedAt)
      .locale("en")
      .format("LLL");
  },

  @computed("period")
  startDate(period) {
    let fullDay = moment()
      .locale("en")
      .utc()
      .subtract(1, "day");

    switch (period) {
      case "yearly":
        return fullDay.subtract(1, "year").startOf("day");
        break;
      case "quarterly":
        return fullDay.subtract(3, "month").startOf("day");
        break;
      case "weekly":
        return fullDay.subtract(1, "week").startOf("day");
        break;
      case "monthly":
        return fullDay.subtract(1, "month").startOf("day");
        break;
      default:
        return fullDay.subtract(1, "month").startOf("day");
    }
  },

  @computed()
  lastWeek() {
    return moment()
      .locale("en")
      .utc()
      .endOf("day")
      .subtract(1, "week");
  },

  @computed()
  endDate() {
    return moment()
      .locale("en")
      .utc()
      .subtract(1, "day")
      .endOf("day");
  },

  @computed("model.attributes.updated_at")
  updatedTimestamp(updatedAt) {
    return moment(updatedAt).format("LLL");
  },

  @computed("lastBackupTakenAt")
  backupTimestamp(lastBackupTakenAt) {
    return moment(lastBackupTakenAt).format("LLL");
  },

  actions: {
    changePeriod(period) {
      DiscourseURL.routeTo(this._reportsForPeriodURL(period));
    },
    refreshProblems() {
      this.loadProblems();
    }
  },

  _reportsForPeriodURL(period) {
    return Discourse.getURL(`/admin?period=${period}`);
  }
});
