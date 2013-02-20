(function() {

  Discourse.UserInvitedController = Ember.ObjectController.extend({
    rescind: function(invite) {
      invite.rescind();
      return false;
    }
  });

}).call(this);
