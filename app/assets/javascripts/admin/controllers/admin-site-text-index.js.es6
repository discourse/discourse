import { default as computed } from 'ember-addons/ember-computed-decorators';

let lastSearch;

export default Ember.Controller.extend({
  _q: null,
  searching: false,
  siteTexts: null,
  preferred: false,
  _overridden: null,
  queryParams: ['q', 'overridden'],

  @computed
  overridden: {
    set(value) {
      if (!value || value === "false") { value = false; }
      this._overridden = value;
      return value;
    },
    get() {
      return this._overridden;
    }
  },

  @computed
  q: {
    set(value) {
      if (Ember.isEmpty(value)) { value = null; }
      this._q = value;
      return value;
    },
    get() {
      return this._q;
    }
  },

  _performSearch() {
    this.store.find('site-text', this.getProperties('q', 'overridden')).then(results => {
      this.set('siteTexts', results);
    }).finally(() => this.set('searching', false));
  },

  actions: {
    edit(siteText) {
      this.transitionToRoute('adminSiteText.edit', siteText.get('id'));
    },

    search() {
      const q = this.get('q');
      if (q !== lastSearch) {
        this.set('searching', true);
        Ember.run.debounce(this, this._performSearch, 400);
        lastSearch = q;
      }
    }
  }
});
