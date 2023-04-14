import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  showFooter: true,

  model() {
    const user = this.modelFor("user");
    if (user.get("profile_hidden")) {
      return this.replaceWith("user.profile-hidden");
    }

    return user.summary();
  },

  titleToken() {
    return I18n.t("user.summary.title");
  },
});
