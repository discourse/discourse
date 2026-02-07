import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import ReseedModal from "discourse/admin/components/modal/reseed";
import discourseDebounce from "discourse/lib/debounce";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

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

  queryParams = [
    "q",
    "overridden",
    "outdated",
    "locale",
    "untranslated",
    "onlySelectedLocale",
  ];
  _page = 0;
  _results = new TrackedArray();
  @tracked _canLoadMore = true;

  get siteTexts() {
    return this._results.flat();
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

  async _performSearch() {
    try {
      this.model = await this.store.find("site-text", {
        q: this.q,
        overridden: this.resolvedOverridden,
        outdated: this.resolvedOutdated,
        locale: this.resolvedLocale,
        untranslated: this.resolvedUntranslated,
        only_selected_locale: this.resolvedOnlySelectedLocale,
        page: this._page,
      });

      if (this._page === 0) {
        this._results.length = 0;
      }

      this._results.push(this.model.content);
      this._canLoadMore = this.model.extras?.has_more ?? false;
    } finally {
      this.searching = false;
    }
  }

  resetSearch() {
    this._page = 0;
    this._results.length = 0;
    this._canLoadMore = true;
    this.searching = true;
    this._performSearch();
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
    if (this.searching || !this._canLoadMore) {
      return;
    }
    this._page += 1;
    this.searching = true;
    this._performSearch();
  }

  @action
  showReseedModal() {
    this.modal.show(ReseedModal);
  }
}
