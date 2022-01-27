import Controller, { inject as controller } from "@ember/controller";
import AdminDashboard from "admin/models/admin-dashboard";
import VersionCheck from "admin/models/version-check";
import { computed } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { setting } from "discourse/lib/computed";

const PROBLEMS_CHECK_MINUTES = 1;

export default Controller.extend({
  isLoading: false,
  dashboardFetchedAt: null,
  exceptionController: controller("exception"),
  showVersionChecks: setting("version_checks"),

  @discourseComputed(
    "lowPriorityProblems.length",
    "highPriorityProblems.length"
  )
  foundProblems(lowPriorityProblemsLength, highPriorityProblemsLength) {
    const problemsLength =
      lowPriorityProblemsLength + highPriorityProblemsLength;
    return this.currentUser.admin && problemsLength > 0;
  },

  visibleTabs: computed("siteSettings.dashboard_visible_tabs", function () {
    return (this.siteSettings.dashboard_visible_tabs || "")
      .split("|")
      .filter(Boolean);
  }),

  isModerationTabVisible: computed("visibleTabs", function () {
    return this.visibleTabs.includes("moderation");
  }),

  isSecurityTabVisible: computed("visibleTabs", function () {
    return this.visibleTabs.includes("security");
  }),

  isReportsTabVisible: computed("visibleTabs", function () {
    return this.visibleTabs.includes("reports");
  }),

  fetchProblems() {
    if (this.isLoadingProblems) {
      return;
    }

    if (
      !this.problemsFetchedAt ||
      moment().subtract(PROBLEMS_CHECK_MINUTES, "minutes").toDate() >
        this.problemsFetchedAt
    ) {
      this._loadProblems();
    }
  },

  fetchDashboard() {
    const versionChecks = this.siteSettings.version_checks;

    if (this.isLoading || !versionChecks) {
      return;
    }

    if (
      !this.dashboardFetchedAt ||
      moment().subtract(30, "minutes").toDate() > this.dashboardFetchedAt
    ) {
      this.set("isLoading", true);

      AdminDashboard.fetch()
        .then((model) => {
          let properties = {
            dashboardFetchedAt: new Date(),
          };

          if (versionChecks) {
            properties.versionCheck = VersionCheck.create(model.version_check);
          }

          this.setProperties(properties);
        })
        .catch((e) => {
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
      problemsFetchedAt: new Date(),
    });

    AdminDashboard.fetchProblems()
      .then((model) => {
        this.set(
          "highPriorityProblems",
          model.problems.filterBy("priority", "high")
        );
        this.set(
          "lowPriorityProblems",
          model.problems.filterBy("priority", "low")
        );
      })
      .finally(() => this.set("loadingProblems", false));
  },

  @discourseComputed("problemsFetchedAt")
  problemsTimestamp(problemsFetchedAt) {
    return moment(problemsFetchedAt).locale("en").format("LLL");
  },

  actions: {
    refreshProblems() {
      this._loadProblems();
    },
  },
});
