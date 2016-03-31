// Lists of topics on a user's page.
export default Ember.Controller.extend({
  needs: ["application", "user"],
  hideCategory: false,
  showPosters: false,

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore"),

  actions: {
    loadMore: function() {
      this.get('model').loadMore();
    }
  },

});
