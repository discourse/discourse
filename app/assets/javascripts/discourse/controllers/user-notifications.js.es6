
export default Ember.ArrayController.extend({
  canLoadMore: true,
  loading: false,
  showDismissButton: function() {
    return this.get('user').total_unread_notifications > 0;
  }.property('user'),

  actions: {
    resetNew: function() {
      Discourse.NotificationContainer.resetNew().then(function() {
        var c = Discourse.__container__.lookup("controller:UserNotifications")
        c.setEach("read", true)
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
          if (notifications && notifications.length === 0) {
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
