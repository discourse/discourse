import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class GroupManageEmail extends DiscourseRoute {
  @service router;

  beforeModel() {
    // cannot configure IMAP without SMTP being enabled
    if (!this.siteSettings.enable_smtp) {
      return this.router.transitionTo("group.manage.profile");
    }
  }

  titleToken() {
    return I18n.t("groups.manage.email.title");
  }
}
