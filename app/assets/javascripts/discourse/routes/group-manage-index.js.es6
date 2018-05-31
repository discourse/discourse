export default Discourse.Route.extend({
  showFooter: true,

  beforeModel() {
    this.transitionTo("group.manage.profile");
  }
});
