import discourseComputed from "discourse-common/utils/decorators";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { setting } from "discourse/lib/computed";
import AdminDashboard from "admin/models/admin-dashboard";
import VersionCheck from "admin/models/version-check";

const PROBLEMS_CHECK_MINUTES = 1;

export default Controller.extend({
  isLoading: false,
  dashboardFetchedAt: null,
  exceptionController: inject("exception"),
  showVersionChecks: setting("version_checks"),

  @discourseComputed("problems.length")
  foundProblems(problemsLength) {
    return this.currentUser.get("admin") && (problemsLength || 0) > 0;
  },

  fetchProblems() {
    if (this.isLoadingProblems) return;

    if (
      !this.problemsFetchedAt ||
      moment()
        .subtract(PROBLEMS_CHECK_MINUTES, "minutes")
        .toDate() > this.problemsFetchedAt
    ) {
      this._loadProblems();
    }
  },

  fetchDashboard() {
    const versionChecks = this.siteSettings.version_checks;

    if (this.isLoading || !versionChecks) return;

    if (
      !this.dashboardFetchedAt ||
      moment()
        .subtract(30, "minutes")
        .toDate() > this.dashboardFetchedAt
    ) {
      this.set("isLoading", true);

      AdminDashboard.fetch()
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
          this.exceptionController.set("thrown", e.jqXHR);
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

    AdminDashboard.fetchProblems()
      .then(model => this.set("problems", model.problems))
      .finally(() => this.set("loadingProblems", false));
  },

  @discourseComputed("problemsFetchedAt")
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
