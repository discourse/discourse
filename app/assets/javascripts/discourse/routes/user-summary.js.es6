export default Discourse.Route.extend({
  showFooter: true,

  model() {
    const user = this.modelFor("user");
    if (!user.profile_hidden) return user.summary();
  },

  actions: {
    didTransition() {
      this.controllerFor("user").set("indexStream", true);
    }
  }
});
