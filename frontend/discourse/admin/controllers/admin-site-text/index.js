import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { service } from "@ember/service";
import ReseedModal from "discourse/admin/components/modal/reseed";
import discourseDebounce from "discourse/lib/debounce";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { i18n } from "discourse-i18n";

let lastSearch;

@disableImplicitInjections
export default class AdminSiteTextIndexController extends Controller {
  @service router;
  @service siteSettings;
  @service modal;
  @service store;

  @tracked locale;
  @tracked q;
  @tracked overridden;
  @tracked outdated;
  @tracked untranslated;
  @tracked onlySelectedLocale;

  @tracked model;

  @tracked searching = false;
  @tracked preferred = false;
  @tracked canLoadMore = true;

  queryParams = [
    "q",
    "overridden",
    "outdated",
    "locale",
    "untranslated",
    "onlySelectedLocale",
  ];

  #page = 0;
  #results = trackedArray();

  get activeFilterCount() {
    return [
      this.resolvedOverridden,
      this.resolvedOutdated,
      this.resolvedOnlySelectedLocale,
      this.resolvedUntranslated,
    ].filter(Boolean).length;
  }

  get hasActiveFilters() {
    return this.activeFilterCount > 0;
  }

  get filterLabel() {
    return this.hasActiveFilters
      ? i18n("admin.site_text.filters_active", {
          count: this.activeFilterCount,
        })
      : i18n("admin.site_text.filters");
  }

  get siteTexts() {
    return this.#results.flat();
  }

  get extras() {
    return this.model?.extras ?? {};
  }

  get resolvedOverridden() {
    return [true, "true"].includes(this.overridden) ?? false;
  }

  get resolvedOutdated() {
    return [true, "true"].includes(this.outdated) ?? false;
  }

  get resolvedUntranslated() {
    return [true, "true"].includes(this.untranslated) ?? false;
  }

  get resolvedOnlySelectedLocale() {
    return [true, "true"].includes(this.onlySelectedLocale) ?? false;
  }

  get resolvedLocale() {
    return this.locale ?? this.siteSettings.default_locale;
  }

  get showUntranslated() {
    return (
      this.siteSettings.admin_allow_filter_untranslated_text &&
      this.resolvedLocale !== "en"
    );
  }

  get availableLocales() {
    return this.siteSettings.available_locales;
  }

  get fallbackLocaleFullName() {
    if (this.model.extras.fallback_locale) {
      return this.availableLocales.find((l) => {
        return l.value === this.model.extras.fallback_locale;
      }).name;
    }
  }

  resetSearch() {
    this.#page = 0;
    this.#results.length = 0;
    this.canLoadMore = true;
    this.searching = true;
    this._performSearch();
  }

  @action
  edit(siteText) {
    this.router.transitionTo("adminSiteText.edit", siteText.get("id"), {
      queryParams: {
        locale: this.resolvedLocale,
      },
    });
  }

  @action
  toggleOverridden() {
    this.overridden = this.resolvedOverridden ? null : true;
    this.resetSearch();
  }

  @action
  toggleOutdated() {
    this.outdated = this.resolvedOutdated ? null : true;
    this.resetSearch();
  }

  @action
  toggleUntranslated() {
    this.untranslated = this.resolvedUntranslated ? null : true;
    this.resetSearch();
  }

  @action
  toggleOnlySelectedLocale() {
    this.onlySelectedLocale = this.resolvedOnlySelectedLocale ? null : true;
    this.resetSearch();
  }

  @action
  resetFilters() {
    this.overridden = null;
    this.outdated = null;
    this.untranslated = null;
    this.onlySelectedLocale = null;
    this.resetSearch();
  }

  @action
  updateSearch(event) {
    this.q = event.target.value;
    this.search();
  }

  @action
  search() {
    const q = this.q;
    if (q !== lastSearch) {
      lastSearch = q;
      discourseDebounce(this, this.resetSearch, 400);
    }
  }

  @action
  updateLocale(value) {
    this.locale = value;
    this.resetSearch();
  }

  @action
  loadMore() {
    if (this.searching || !this.canLoadMore) {
      return;
    }
    this.#page += 1;
    this.searching = true;
    this._performSearch();
  }

  @action
  showReseedModal() {
    this.modal.show(ReseedModal);
  }

  async _performSearch() {
    try {
      this.model = await this.store.find("site-text", {
        q: this.q,
        overridden: this.resolvedOverridden,
        outdated: this.resolvedOutdated,
        locale: this.resolvedLocale,
        untranslated: this.resolvedUntranslated,
        only_selected_locale: this.resolvedOnlySelectedLocale,
        page: this.#page,
      });

      if (this.#page === 0) {
        this.#results.length = 0;
      }

      this.#results.push(this.model.content);
      this.canLoadMore = this.model.extras?.has_more ?? false;
    } finally {
      this.searching = false;
    }
  }
}
