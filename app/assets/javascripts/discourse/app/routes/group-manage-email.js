import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupManageEmail extends DiscourseRoute {
  @service router;

  beforeModel() {
    // cannot configure IMAP without SMTP being enabled
    if (!this.siteSettings.enable_smtp) {
      return this.router.transitionTo("group.manage.profile");
    }
  }

  titleToken() {
    return i18n("groups.manage.email.title");
  }
}
