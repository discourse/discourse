(function() {

  Discourse.UserActivityController = Ember.ObjectController.extend({
    needs: ['composer'],
    kickOffPrivateMessage: (function() {
      if (this.get('content.openPrivateMessage')) {
        return this.composePrivateMessage();
      }
    }).observes('content.openPrivateMessage'),
    composePrivateMessage: function() {
      return this.get('controllers.composer').open({
        action: Discourse.Composer.PRIVATE_MESSAGE,
        usernames: this.get('content').username,
        archetypeId: 'private_message',
        draftKey: 'new_private_message'
      });
    }
  });

}).call(this);
