import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  model() {
    const user = this.modelFor("user");
    if (user.get("profile_hidden")) {
      return this.router.replaceWith("user.profile-hidden");
    }

    return user.summary();
  },

  titleToken() {
    return I18n.t("user.summary.title");
  },
});
