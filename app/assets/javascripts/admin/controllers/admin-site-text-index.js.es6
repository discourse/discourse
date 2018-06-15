let lastSearch;
let lastOverridden;

export default Ember.Controller.extend({
  searching: false,
  siteTexts: null,
  preferred: false,
  queryParams: ["q", "overridden"],

  q: null,
  overridden: null,

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

    search(overridden) {
      this.set("overridden", overridden);

      const q = this.get("q");
      if (q !== lastSearch || overridden !== lastOverridden) {
        this.set("searching", true);
        Ember.run.debounce(this, this._performSearch, 400);
        lastSearch = q;
        lastOverridden = overridden;
      }
    }
  }
});
