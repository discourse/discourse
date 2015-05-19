export default Ember.ArrayController.extend({
  needs: ['application'],

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore"),

  showDismissButton: Ember.computed.gt('user.total_unread_notifications', 0),

  actions: {
    resetNew: function() {
      Discourse.ajax('/notifications/mark-read', { method: 'PUT' }).then(() => {
        this.setEach('read', true);
      });
    },

    loadMore: function() {
      this.get('model').loadMore();
    }
  }
});
