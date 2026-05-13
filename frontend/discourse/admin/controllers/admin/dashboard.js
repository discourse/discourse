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
import { ajax } from "discourse/lib/ajax";
import { autoTrackedArray } from "discourse/lib/tracked-tools";

const PROBLEMS_CHECK_MINUTES = 1;

export default class AdminDashboardController extends Controller {
  @service router;
  @service siteSettings;
  @controller("exception") exceptionController;

  @tracked loadingProblems = false;
  @tracked problemsFetchedAt;
  @tracked range = DEFAULT_PERIOD;
  @tracked start_date = null;
  @tracked end_date = null;
  @tracked sections = null;
  @tracked configuration = null;
  @tracked loadingSections = false;
  @tracked sectionsFetchError = false;
  @autoTrackedArray problems;

  queryParams = ["range", "start_date", "end_date"];

  isLoading = false;
  dashboardFetchedAt = null;
  _sectionsLoadId = 0;

  get safePeriod() {
    if (!VALID_PERIODS.includes(this.range)) {
      return DEFAULT_PERIOD;
    }
    if (this.range === PERIOD_CUSTOM && (!this.start_date || !this.end_date)) {
      return DEFAULT_PERIOD;
    }
    return this.range;
  }

  get startDate() {
    if (this.safePeriod === PERIOD_CUSTOM && this.start_date) {
      const parsed = moment(this.start_date, "YYYY-MM-DD", true);
      if (parsed.isValid()) {
        return parsed.startOf("day").toDate();
      }
    }
    return calculatePresetStartDate(this.safePeriod);
  }

  get endDate() {
    if (this.safePeriod === PERIOD_CUSTOM && this.end_date) {
      const parsed = moment(this.end_date, "YYYY-MM-DD", true);
      if (parsed.isValid()) {
        return parsed.endOf("day").toDate();
      }
    }
    return moment().endOf("day").toDate();
  }

  @action
  setPeriod(period) {
    this.range = period;
    this.start_date = null;
    this.end_date = null;
    this.fetchSections();
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.range = PERIOD_CUSTOM;
    this.start_date = moment(startDate).format("YYYY-MM-DD");
    this.end_date = moment(endDate).format("YYYY-MM-DD");
    this.fetchSections();
  }

  @action
  async updateConfiguration(sections) {
    await ajax("/admin/dashboard/configuration.json", {
      type: "PUT",
      contentType: "application/json",
      data: JSON.stringify({ sections }),
    });
    await this.fetchSections();
  }

  async fetchSections() {
    const id = ++this._sectionsLoadId;
    this.loadingSections = true;
    this.sectionsFetchError = false;

    try {
      const model = await AdminDashboard.fetch({
        startDate: this.startDate,
        endDate: this.endDate,
      });
      if (id !== this._sectionsLoadId) {
        return;
      }
      this.sections = model.sections;
      this.configuration = model.configuration;
    } catch {
      if (id !== this._sectionsLoadId) {
        return;
      }
      this.sectionsFetchError = true;
    } finally {
      if (id === this._sectionsLoadId) {
        this.loadingSections = false;
      }
    }
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
