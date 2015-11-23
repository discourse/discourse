import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  _q: null,
  searching: false,
  siteTexts: null,
  preferred: false,

  queryParams: ['q'],

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
    const q = this.get('q');
    this.store.find('site-text', { q }).then(results => {
      this.set('siteTexts', results);
    }).finally(() => this.set('searching', false));
  },

  actions: {
    edit(siteText) {
      this.transitionToRoute('adminSiteText.edit', siteText.get('id'));
    },

    search() {
      this.set('searching', true);
      Ember.run.debounce(this, this._performSearch, 400);
    }
  }
});
