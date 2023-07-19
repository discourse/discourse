import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

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
  },

  titleToken() {
    return I18n.t("user.activity_stream");
  },
});
