export default Discourse.Route.extend({
  beforeModel() {
    this.transitionTo("group.manage.profile");
  }
});
