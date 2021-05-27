import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  showFooter: true,

  beforeModel() {
    // cannot configure IMAP without SMTP being enabled
    if (!this.siteSettings.enable_smtp) {
      return this.transitionTo("group.manage.profile");
    }
  },

  titleToken() {
    return I18n.t("groups.manage.email.title");
  },
});
