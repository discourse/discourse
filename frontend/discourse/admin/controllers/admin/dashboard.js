import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import {
  calculatePresetStartDate,
  DEFAULT_PERIOD,
  PERIOD_CUSTOM,
  VALID_PERIODS,
} from "discourse/admin/lib/dashboard-date-range";
import AdminDashboard from "discourse/admin/models/admin-dashboard";
import VersionCheck from "discourse/admin/models/version-check";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { autoTrackedArray } from "discourse/lib/tracked-tools";

const PROBLEMS_CHECK_MINUTES = 1;

export default class AdminDashboardController extends Controller {
  @service router;
  @service siteSettings;
  @service loadingSlider;
  @controller("exception") exceptionController;

  @tracked loadingProblems = false;
  @tracked problemsFetchedAt;
  @tracked range = DEFAULT_PERIOD;
  @tracked start_date = null;
  @tracked end_date = null;
  @tracked version = null;
  @tracked loadedSections = null;
  @tracked loadingSections = false;
  @tracked sectionsFetchError = false;
  @autoTrackedArray problems;

  queryParams = ["range", "start_date", "end_date", "version"];

  isLoading = false;
  dashboardFetchedAt = null;
  _sectionsLoadId = 0;
  _sectionsLoadingCount = 0;
  _configSaveId = 0;
  _sectionDataCache = new Map();

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
    return (
      this.#customDate(this.start_date, "startOf") ??
      calculatePresetStartDate(this.safePeriod)
    );
  }

  get endDate() {
    return (
      this.#customDate(this.end_date, "endOf") ?? moment().endOf("day").toDate()
    );
  }

  #customDate(value, edge) {
    if (this.safePeriod !== PERIOD_CUSTOM || !value) {
      return null;
    }
    const parsed = moment(value, "YYYY-MM-DD", true);
    return parsed.isValid() ? parsed[edge]("day").toDate() : null;
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
  toggleSection(id) {
    const previous = this.loadedSections;
    const current = previous?.configuration?.sections ?? [];
    const wasVisible = current.find((s) => s.id === id)?.visible;
    const nextConfig = current.map((s) =>
      s.id === id ? { ...s, visible: !s.visible } : s
    );

    this.#applyConfigOptimistically(nextConfig);

    const needsRefetch = !wasVisible && !this._sectionDataCache.has(id);
    this.#persistConfiguration(nextConfig, previous, { needsRefetch });
  }

  @action
  reorderSections(fromIndex, toIndex) {
    const previous = this.loadedSections;
    const nextConfig = [...(previous?.configuration?.sections ?? [])];
    const [moved] = nextConfig.splice(fromIndex, 1);
    nextConfig.splice(toIndex, 0, moved);

    this.#applyConfigOptimistically(nextConfig);
    this.#persistConfiguration(nextConfig, previous, { needsRefetch: false });
  }

  #applyConfigOptimistically(nextConfig) {
    for (const section of this.loadedSections?.sections ?? []) {
      this._sectionDataCache.set(section.id, section.data);
    }

    this.loadedSections = {
      ...this.loadedSections,
      sections: nextConfig
        .filter((s) => s.visible && this._sectionDataCache.has(s.id))
        .map((s) => ({ id: s.id, data: this._sectionDataCache.get(s.id) })),
      configuration: { sections: nextConfig },
    };
  }

  async #persistConfiguration(sections, revertTo, { needsRefetch } = {}) {
    const saveId = ++this._configSaveId;

    try {
      await ajax("/admin/dashboard/configuration.json", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ sections }),
      });

      if (needsRefetch && saveId === this._configSaveId) {
        await this.fetchSections();
      }
    } catch (e) {
      if (saveId === this._configSaveId) {
        this.loadedSections = revertTo;
      }
      popupAjaxError(e);
    }
  }

  @action
  async fetchSections() {
    const id = ++this._sectionsLoadId;
    const period = this.safePeriod;
    const startDate = this.startDate;
    const endDate = this.endDate;

    this.loadingSections = true;
    this.sectionsFetchError = false;

    this._sectionsLoadingCount += 1;
    if (this._sectionsLoadingCount === 1) {
      this.loadingSlider.transitionStarted();
    }

    try {
      const model = await AdminDashboard.fetch({
        startDate,
        endDate,
        version: this.version,
      });

      if (id !== this._sectionsLoadId) {
        return;
      }

      this.loadedSections = {
        period,
        startDate,
        endDate,
        sections: model.sections,
        configuration: model.configuration,
      };
      this.problems = model.problems;
    } catch {
      if (id !== this._sectionsLoadId) {
        return;
      }
      this.sectionsFetchError = true;
    } finally {
      this._sectionsLoadingCount = Math.max(this._sectionsLoadingCount - 1, 0);
      if (this._sectionsLoadingCount === 0) {
        this.loadingSlider.transitionEnded();
      }

      if (id === this._sectionsLoadId) {
        this.loadingSections = false;
      }
    }
  }

  get showRedesign() {
    if (this.version === "alt") {
      return !this.siteSettings.dashboard_improvements;
    }
    return this.siteSettings.dashboard_improvements;
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

      AdminDashboard.fetch({ version: this.version })
        .then((model) => {
          let properties = {
            dashboardFetchedAt: new Date(),
          };

          if (versionChecks) {
            properties.versionCheck = new VersionCheck(model.version_check);
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

  @action
  async refreshSiteAdvice() {
    try {
      const model = await AdminDashboard.fetchProblems();
      this.problems = model.problems;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async ignoreProblem(problem) {
    try {
      await ajax(`/admin/admin_notices/${problem.id}`, { type: "DELETE" });
      this.problems = this.problems.filter(
        (candidate) => candidate.id !== problem.id
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
