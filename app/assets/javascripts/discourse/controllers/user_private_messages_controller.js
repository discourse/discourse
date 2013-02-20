(function() {

  Discourse.UserPrivateMessagesController = Ember.ObjectController.extend({
    editPreferences: function() {
      return Discourse.routeTo("/users/" + (this.get('content.username_lower')) + "/preferences");
    },
    composePrivateMessage: function() {
      var composerController;
      composerController = Discourse.get('router.composerController');
      return composerController.open({
        action: Discourse.Composer.PRIVATE_MESSAGE,
        archetypeId: 'private_message',
        draftKey: 'new_private_message'
      });
    }
  });

}).call(this);
