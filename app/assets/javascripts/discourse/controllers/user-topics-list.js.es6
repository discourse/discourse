import ObjectController from 'discourse/controllers/object';

// Lists of topics on a user's page.
export default ObjectController.extend(Discourse.HasCurrentUser, {
  needs: ["application", "user"],
  hideCategory: false,
  showParticipants: false,

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("canLoadMore"));
  }.observes("canLoadMore"),

  actions: {
    loadMore: function() {
      this.get('model').loadMore();
    }
  },

  showNewPM: function(){
    return this.get('controllers.user.viewingSelf') &&
           Discourse.User.currentProp('can_send_private_messages');
  }.property('controllers.user.viewingSelf'),

});
