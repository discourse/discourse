export default Ember.ArrayController.extend({
  showAdminLinks: Em.computed.alias("currentUser.staff"),

  actions: {
    logout() {
      Discourse.logout();
      return false;
    }
  }
});
