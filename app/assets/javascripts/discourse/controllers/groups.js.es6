import { observes } from 'ember-addons/ember-computed-decorators';
import debounce from 'discourse/lib/debounce';

export default Ember.Controller.extend({
  application: Ember.inject.controller(),
  queryParams: ["order", "asc", "filter"],
  order: null,
  asc: null,
  filter: "",
  filterInput: "",

  @observes("filterInput")
  _setFilter: debounce(function() {
    this.set("filter", this.get("filterInput"));
  }, 500),

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
