import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import {
  calculatePresetStartDate,
  DEFAULT_PERIOD,
  PERIOD_CUSTOM,
  VALID_PERIODS,
} from "discourse/admin/components/dashboard/date-range";
import AdminDashboard from "discourse/admin/models/admin-dashboard";
import VersionCheck from "discourse/admin/models/version-check";
import { autoTrackedArray } from "discourse/lib/tracked-tools";

const PROBLEMS_CHECK_MINUTES = 1;

export default class AdminDashboardController extends Controller {
  @service router;
  @service siteSettings;
  @controller("exception") exceptionController;

  @tracked loadingProblems = false;
  @tracked problemsFetchedAt;
  @tracked range = DEFAULT_PERIOD;
  @tracked from = null;
  @tracked to = null;
  @autoTrackedArray problems;

  queryParams = ["range", "from", "to"];

  isLoading = false;
  dashboardFetchedAt = null;

  get safePeriod() {
    if (!VALID_PERIODS.includes(this.range)) {
      return DEFAULT_PERIOD;
    }
    if (this.range === PERIOD_CUSTOM && (!this.from || !this.to)) {
      return DEFAULT_PERIOD;
    }
    return this.range;
  }

  get startDate() {
    if (this.safePeriod === PERIOD_CUSTOM && this.from) {
      const parsed = moment(this.from, "YYYY-MM-DD", true);
      if (parsed.isValid()) {
        return parsed.startOf("day").toDate();
      }
    }
    return calculatePresetStartDate(this.safePeriod);
  }

  get endDate() {
    if (this.safePeriod === PERIOD_CUSTOM && this.to) {
      const parsed = moment(this.to, "YYYY-MM-DD", true);
      if (parsed.isValid()) {
        return parsed.endOf("day").toDate();
      }
    }
    return moment().endOf("day").toDate();
  }

  @action
  setPeriod(period) {
    this.range = period;
    this.from = null;
    this.to = null;
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.range = PERIOD_CUSTOM;
    this.from = moment(startDate).format("YYYY-MM-DD");
    this.to = moment(endDate).format("YYYY-MM-DD");
  }

  @computed("siteSettings.version_checks")
  get showVersionChecks() {
    return this.siteSettings.version_checks;
  }

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

  async _loadProblems() {
    this.setProperties({
      loadingProblems: true,
      problemsFetchedAt: new Date(),
    });

    try {
      const model = await AdminDashboard.fetchProblems();
      this.problems = model.problems;
    } finally {
      this.loadingProblems = false;
    }
  }

  @computed("problemsFetchedAt")
  get problemsTimestamp() {
    return moment(this.problemsFetchedAt).format("LLL");
  }

  @action
  refreshProblems() {
    this._loadProblems();
  }
}
