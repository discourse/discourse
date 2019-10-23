import Controller from "@ember/controller";
let lastSearch;

export default Controller.extend({
  searching: false,
  siteTexts: null,
  preferred: false,
  queryParams: ["q", "overridden"],

  q: null,
  overridden: false,

  _performSearch() {
    this.store
      .find("site-text", this.getProperties("q", "overridden"))
      .then(results => {
        this.set("siteTexts", results);
      })
      .finally(() => this.set("searching", false));
  },

  actions: {
    edit(siteText) {
      this.transitionToRoute("adminSiteText.edit", siteText.get("id"));
    },

    toggleOverridden() {
      this.toggleProperty("overridden");
      this.set("searching", true);
      Ember.run.debounce(this, this._performSearch, 400);
    },

    search() {
      const q = this.q;
      if (q !== lastSearch) {
        this.set("searching", true);
        Ember.run.debounce(this, this._performSearch, 400);
        lastSearch = q;
      }
    }
  }
});
