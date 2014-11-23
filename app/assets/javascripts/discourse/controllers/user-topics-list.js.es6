import ObjectController from 'discourse/controllers/object';

// Lists of topics on a user's page.
export default ObjectController.extend({
  needs: ["application"],
  hideCategory: false,
  showParticipants: false,

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("canLoadMore"));
  }.observes("canLoadMore"),

  actions: {
    loadMore: function() {
      this.get('model').loadMore();
    }
  }

});
