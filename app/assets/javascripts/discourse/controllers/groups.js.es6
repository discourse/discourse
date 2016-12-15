import { observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  @observes("groups.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("groups.canLoadMore"));
  },

  actions: {
    loadMore() {
      this.get('groups').loadMore();
    }
  }
});
