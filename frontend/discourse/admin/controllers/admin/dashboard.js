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
  _sectionCache = new Map();
  _sectionRequestIds = new Map();

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
    const nextConfig = current.map((s) =>
      s.id === id ? { ...s, visible: !s.visible } : s
    );

    this.#applyConfigOptimistically(nextConfig);
    this.#persistConfiguration(nextConfig, previous);
  }

  @action
  reorderSections(fromIndex, toIndex) {
    const previous = this.loadedSections;
    const nextConfig = [...(previous?.configuration?.sections ?? [])];
    const [moved] = nextConfig.splice(fromIndex, 1);
    nextConfig.splice(toIndex, 0, moved);

    this.#applyConfigOptimistically(nextConfig);
    this.#persistConfiguration(nextConfig, previous);
  }

  #applyConfigOptimistically(nextConfig) {
    const currentSections = new Map(
      this.loadedSections?.sections.map((section) => [section.id, section])
    );

    for (const section of currentSections.values()) {
      if (section.loaded) {
        this._sectionCache.set(section.id, section);
      }
    }

    this.loadedSections = {
      ...this.loadedSections,
      sections: nextConfig
        .filter((section) => section.visible)
        .map((section) => {
          const currentSection = currentSections.get(section.id);
          if (currentSection) {
            return currentSection;
          }

          const cachedSection = this._sectionCache.get(section.id);
          return (
            cachedSection ?? {
              id: section.id,
              data: null,
              loaded: false,
              loading: false,
              error: false,
              stale: false,
            }
          );
        }),
      configuration: { sections: nextConfig },
    };
  }

  async #persistConfiguration(sections, revertTo) {
    const saveId = ++this._configSaveId;

    try {
      await ajax("/admin/dashboard/configuration.json", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ sections }),
      });
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

    this._sectionCache.clear();
    this.loadingSections = true;
    this.sectionsFetchError = false;

    if (this.loadedSections) {
      this.loadedSections = {
        ...this.loadedSections,
        period,
        startDate,
        endDate,
        sections: this.loadedSections.sections.map((section) =>
          section.loaded
            ? {
                ...section,
                loading: false,
                error: false,
                stale: true,
              }
            : {
                id: section.id,
                data: null,
                loaded: false,
                loading: false,
                error: false,
                stale: false,
              }
        ),
      };
    }

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

      const currentSections = new Map(
        this.loadedSections?.sections.map((section) => [section.id, section])
      );

      this.loadedSections = {
        period,
        startDate,
        endDate,
        sections: model.sections.map(
          (section) =>
            currentSections.get(section.id) ?? {
              id: section.id,
              data: null,
              loaded: false,
              loading: false,
              error: false,
              stale: false,
            }
        ),
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

  @action
  async loadSection(sectionId, intersection) {
    if (intersection && !intersection.isIntersecting) {
      return;
    }

    const section = this.loadedSections?.sections.find(
      (candidate) => candidate.id === sectionId
    );
    if (!section || section.loading || (section.loaded && !section.stale)) {
      return;
    }

    const loadId = this._sectionsLoadId;
    const requestId = (this._sectionRequestIds.get(sectionId) ?? 0) + 1;
    this._sectionRequestIds.set(sectionId, requestId);
    this.#updateSection(sectionId, { loading: true, error: false });

    try {
      const result = await AdminDashboard.fetchSection(sectionId, {
        startDate: this.loadedSections.startDate,
        endDate: this.loadedSections.endDate,
        version: this.version,
      });

      if (
        loadId !== this._sectionsLoadId ||
        requestId !== this._sectionRequestIds.get(sectionId)
      ) {
        return;
      }

      const loadedSection = {
        ...section,
        data: result.data,
        loaded: true,
        loading: false,
        error: false,
        stale: false,
        period: this.loadedSections.period,
        startDate: this.loadedSections.startDate,
        endDate: this.loadedSections.endDate,
      };
      this._sectionCache.set(sectionId, loadedSection);
      this.#updateSection(sectionId, loadedSection);
    } catch {
      if (
        loadId === this._sectionsLoadId &&
        requestId === this._sectionRequestIds.get(sectionId)
      ) {
        this.#updateSection(sectionId, {
          loaded: section.loaded,
          loading: false,
          error: true,
          stale: section.loaded,
        });
      }
    }
  }

  @action
  async refreshSection(sectionId) {
    this.#updateSection(sectionId, {
      loading: false,
      error: false,
      stale: true,
    });
    await this.loadSection(sectionId);
  }

  @action
  retrySection(sectionId) {
    this.#updateSection(sectionId, { error: false });
    this.loadSection(sectionId);
  }

  #updateSection(sectionId, attributes) {
    this.loadedSections = {
      ...this.loadedSections,
      sections: this.loadedSections.sections.map((section) =>
        section.id === sectionId ? { ...section, ...attributes } : section
      ),
    };
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
