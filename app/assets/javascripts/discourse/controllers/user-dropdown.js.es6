export default Ember.ArrayController.extend(Discourse.HasCurrentUser, {
  showAdminLinks: Em.computed.alias("currentUser.staff"),

  actions: {
    logout: function() {
      Discourse.logout();
      return false;
    }
  }
});
