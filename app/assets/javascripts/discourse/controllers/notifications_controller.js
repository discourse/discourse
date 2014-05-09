Discourse.NotificationsController = Ember.ArrayController.extend(Discourse.HasCurrentUser, {
  needs: ['header'],
  itemController: "notification"
});
