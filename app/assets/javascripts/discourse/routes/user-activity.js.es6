import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    let user = this.modelFor("user");
    if (user.get("profile_hidden")) {
      return this.replaceWith("user.profile-hidden");
    }

    return user;
  },

  setupController(controller, user) {
    this.controllerFor("user-activity").set("model", user);
  }
});
