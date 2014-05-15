export default Ember.ObjectController.extend({
  showBadges: function() {
    return !!Discourse.User.current();
  }.property().volatile()
});
