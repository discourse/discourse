import { setting } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";
import AdminDashboardNext from "admin/models/admin-dashboard-next";
import VersionCheck from "admin/models/version-check";

const PROBLEMS_CHECK_MINUTES = 1;

export default Ember.Controller.extend({
  isLoading: false,
  dashboardFetchedAt: null,
  exceptionController: Ember.inject.controller("exception"),
  showVersionChecks: setting("version_checks"),

  @computed("problems.length")
  foundProblems(problemsLength) {
    return this.currentUser.get("admin") && (problemsLength || 0) > 0;
  },

  fetchProblems() {
    if (this.get("isLoadingProblems")) return;

    if (
      !this.get("problemsFetchedAt") ||
      moment()
        .subtract(PROBLEMS_CHECK_MINUTES, "minutes")
        .toDate() > this.get("problemsFetchedAt")
    ) {
      this._loadProblems();
    }
  },

  fetchDashboard() {
    const versionChecks = this.siteSettings.version_checks;

    if (this.get("isLoading") || !versionChecks) return;

    if (
      !this.get("dashboardFetchedAt") ||
      moment()
        .subtract(30, "minutes")
        .toDate() > this.get("dashboardFetchedAt")
    ) {
      this.set("isLoading", true);

      AdminDashboardNext.fetch()
        .then(model => {
          let properties = {
            dashboardFetchedAt: new Date()
          };

          if (versionChecks) {
            properties.versionCheck = VersionCheck.create(model.version_check);
          }

          this.setProperties(properties);
        })
        .catch(e => {
          this.get("exceptionController").set("thrown", e.jqXHR);
          this.replaceRoute("exception");
        })
        .finally(() => {
          this.set("isLoading", false);
        });
    }
  },

  _loadProblems() {
    this.setProperties({
      loadingProblems: true,
      problemsFetchedAt: new Date()
    });

    AdminDashboardNext.fetchProblems()
      .then(model => this.set("problems", model.problems))
      .finally(() => this.set("loadingProblems", false));
  },

  @computed("problemsFetchedAt")
  problemsTimestamp(problemsFetchedAt) {
    return moment(problemsFetchedAt)
      .locale("en")
      .format("LLL");
  },

  actions: {
    refreshProblems() {
      this._loadProblems();
    }
  }
});
