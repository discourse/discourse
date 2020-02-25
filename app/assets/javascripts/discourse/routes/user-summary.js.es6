import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  showFooter: true,

  model() {
    const user = this.modelFor("user");
    if (user.get("profile_hidden")) {
      return this.replaceWith("user.profile-hidden");
    }

    return user.summary();
  },

  actions: {
    didTransition() {
      this.controllerFor("user").set("indexStream", true);
    }
  }
});
