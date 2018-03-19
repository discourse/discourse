import { observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  application: Ember.inject.controller(),
  queryParams: ["order", "asc"],
  order: null,
  asc: null,

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  actions: {
    loadMore() {
      this.get('model').loadMore();
    }
  }
});
