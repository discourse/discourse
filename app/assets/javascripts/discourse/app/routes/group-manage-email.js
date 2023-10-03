import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  beforeModel() {
    // cannot configure IMAP without SMTP being enabled
    if (!this.siteSettings.enable_smtp) {
      return this.router.transitionTo("group.manage.profile");
    }
  },

  titleToken() {
    return I18n.t("groups.manage.email.title");
  },
});
