
export default Ember.ArrayController.extend({
  canLoadMore: true,
  loading: false,

  actions: {
    loadMore: function() {
      if (this.get('canLoadMore') && !this.get('loading')) {
        this.set('loading', true);
        var self = this;
        Discourse.NotificationContainer.loadHistory(
            self.get('model.lastObject.created_at'),
            self.get('user.username')).then(function(result) {
          self.set('loading', false);
          self.pushObjects(result);
          // Stop trying if it's the end
          if (result.length === 0) {
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
