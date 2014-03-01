Discourse.NotificationsController = Ember.ArrayController.extend(Discourse.HasCurrentUser, {
  itemController: "notification"
});
