export default Discourse.Route.extend({
  redirect: function() {
    this.transitionTo("adminUsersList");
  }
});
