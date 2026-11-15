import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  calculatePresetStartDate,
  DEFAULT_PERIOD,
  PERIOD_CUSTOM,
  VALID_PERIODS,
} from "discourse/admin/lib/dashboard-date-range";
import AdminDashboard from "discourse/admin/models/admin-dashboard";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { autoTrackedArray } from "discourse/lib/tracked-tools";

/**
 * @typedef {Object} LoadedDashboardSections
 * @property {string} [period]
 * @property {Date} [startDate]
 * @property {Date} [endDate]
 * @property {{ id: string, data?: unknown, error?: boolean }[]} sections
 * @property {{ sections: { id: string, visible: boolean }[] }} [configuration]
 */
export default class AdminDashboardController extends Controller {
  @service loadingSlider;

  @tracked range = DEFAULT_PERIOD;

  /** @type {string | null} */
  @tracked start_date = null;

  /** @type {string | null} */
  @tracked end_date = null;

  /** @type {LoadedDashboardSections | null} */
  @tracked loadedSections = null;
  @tracked loadingSections = false;
  @tracked sectionsFetchError = false;
  @autoTrackedArray problems;

  queryParams = ["range", "start_date", "end_date"];

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
      this.loadingSlider.transitionStarted({ showFallbackSpinner: false });
    }

    try {
      const model = await AdminDashboard.fetch({ startDate, endDate });

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

  #customDate(value, edge) {
    if (this.safePeriod !== PERIOD_CUSTOM || !value) {
      return null;
    }
    const parsed = moment(value, "YYYY-MM-DD", true);
    return parsed.isValid() ? parsed[edge]("day").toDate() : null;
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
}
