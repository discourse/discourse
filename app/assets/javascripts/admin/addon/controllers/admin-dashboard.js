import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { setting } from "discourse/lib/computed";
import discourseComputed from "discourse-common/utils/decorators";
import AdminDashboard from "admin/models/admin-dashboard";
import VersionCheck from "admin/models/version-check";

const PROBLEMS_CHECK_MINUTES = 1;

export default class AdminDashboardController extends Controller {
  @service router;
  @service siteSettings;
  @controller("exception") exceptionController;

  isLoading = false;
  dashboardFetchedAt = null;

  @setting("version_checks") showVersionChecks;

  @computed("siteSettings.dashboard_visible_tabs")
  get visibleTabs() {
    return (this.siteSettings.dashboard_visible_tabs || "")
      .split("|")
      .filter(Boolean);
  }

  @computed("visibleTabs")
  get isModerationTabVisible() {
    return this.visibleTabs.includes("moderation");
  }

  @computed("visibleTabs")
  get isSecurityTabVisible() {
    return this.visibleTabs.includes("security");
  }

  @computed("visibleTabs")
  get isReportsTabVisible() {
    return this.visibleTabs.includes("reports");
  }

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
  }

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
          this.router.replaceWith("exception");
        })
        .finally(() => {
          this.set("isLoading", false);
        });
    }
  }

  _loadProblems() {
    this.setProperties({
      loadingProblems: true,
      problemsFetchedAt: new Date(),
    });

    AdminDashboard.fetchProblems()
      .then((model) => this.set("problems", model.problems))
      .finally(() => this.set("loadingProblems", false));
  }

  @discourseComputed("problemsFetchedAt")
  problemsTimestamp(problemsFetchedAt) {
    return moment(problemsFetchedAt).format("LLL");
  }

  @action
  refreshProblems() {
    this._loadProblems();
  }
}
