
export default Ember.ArrayController.extend({
  needs: ['user-notifications', 'application'],
  loading: false,

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("canLoadMore"));
  }.observes("canLoadMore"),

  showDismissButton: function() {
    return this.get('user').total_unread_notifications > 0;
  }.property('user'),

  actions: {
    resetNew: function() {
      var self = this;
      Discourse.NotificationContainer.resetNew().then(function() {
        self.get('controllers.user-notifications').setEach('read', true);
      });
    },

    loadMore: function() {
      if (this.get('canLoadMore') && !this.get('loading')) {
        this.set('loading', true);
        var self = this;
        Discourse.NotificationContainer.loadHistory(
            self.get('model.lastObject.created_at'),
            self.get('user.username')).then(function(result) {
          self.set('loading', false);
          var notifications = result.get('content');
          self.pushObjects(notifications);
          // Stop trying if it's the end
          if (notifications && (notifications.length === 0 || notifications.length < 60)) {
            self.set('canLoadMore', false);
          }
        }).catch(function(error) {
          self.set('loading', false);
          Em.Logger.error(error);
        });
      }
    }
  }
});
