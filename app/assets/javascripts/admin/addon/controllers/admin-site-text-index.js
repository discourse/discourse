import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
let lastSearch;

export default Controller.extend({
  searching: false,
  siteTexts: null,
  preferred: false,
  queryParams: ["q", "overridden", "locale"],
  locale: null,

  q: null,
  overridden: false,

  init() {
    this._super(...arguments);

    this.set("locale", this.siteSettings.default_locale);
  },

  _performSearch() {
    this.store
      .find("site-text", this.getProperties("q", "overridden", "locale"))
      .then((results) => {
        this.set("siteTexts", results);
      })
      .finally(() => this.set("searching", false));
  },

  @discourseComputed()
  availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
  },

  @discourseComputed("locale")
  fallbackLocaleFullName() {
    if (this.siteTexts.extras.fallback_locale) {
      return this.availableLocales.find((l) => {
        return l.value === this.siteTexts.extras.fallback_locale;
      }).name;
    }
  },

  actions: {
    edit(siteText) {
      this.transitionToRoute("adminSiteText.edit", siteText.get("id"), {
        queryParams: {
          locale: this.locale,
        },
      });
    },

    toggleOverridden() {
      this.toggleProperty("overridden");
      this.set("searching", true);
      discourseDebounce(this, this._performSearch, 400);
    },

    search() {
      const q = this.q;
      if (q !== lastSearch) {
        this.set("searching", true);
        discourseDebounce(this, this._performSearch, 400);
        lastSearch = q;
      }
    },

    updateLocale(value) {
      this.setProperties({
        searching: true,
        locale: value,
      });

      discourseDebounce(this, this._performSearch, 400);
    },
  },
});
