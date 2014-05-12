export default Ember.ArrayController.extend(Discourse.HasCurrentUser, {
  needs: ['header'],
  itemController: "notification"
});
