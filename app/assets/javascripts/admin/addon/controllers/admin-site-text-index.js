import { action } from "@ember/object";
import Controller from "@ember/controller";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import ReseedModal from "admin/components/modal/reseed";

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

  @tracked model;

  @tracked searching = false;
  @tracked preferred = false;

  queryParams = ["q", "overridden", "outdated", "locale"];

  get resolvedOverridden() {
    return [true, "true"].includes(this.overridden) ?? false;
  }

  get resolvedOutdated() {
    return [true, "true"].includes(this.outdated) ?? false;
  }

  get resolvedLocale() {
    return this.locale ?? this.siteSettings.default_locale;
  }

  async _performSearch() {
    try {
      this.model = await this.store.find("site-text", {
        q: this.q,
        overridden: this.resolvedOverridden,
        outdated: this.resolvedOutdated,
        locale: this.resolvedLocale,
      });
    } finally {
      this.searching = false;
    }
  }

  get availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
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
    if (this.resolvedOverridden) {
      this.overridden = null;
    } else {
      this.overridden = true;
    }
    this.searching = true;
    discourseDebounce(this, this._performSearch, 400);
  }

  @action
  toggleOutdated() {
    if (this.resolvedOutdated) {
      this.outdated = null;
    } else {
      this.outdated = true;
    }
    this.searching = true;
    discourseDebounce(this, this._performSearch, 400);
  }

  @action
  search() {
    const q = this.q;
    if (q !== lastSearch) {
      this.searching = true;
      discourseDebounce(this, this._performSearch, 400);
      lastSearch = q;
    }
  }

  @action
  updateLocale(value) {
    this.searching = true;
    this.locale = value;

    discourseDebounce(this, this._performSearch, 400);
  }

  @action
  showReseedModal() {
    this.modal.show(ReseedModal);
  }
}
