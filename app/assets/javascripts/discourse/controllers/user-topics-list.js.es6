// Lists of topics on a user's page.
export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  hideCategory: false,
  showPosters: false,

  _showFooter: function() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore"),

  actions: {
    loadMore: function() {
      this.get('model').loadMore();
    }
  },

});
