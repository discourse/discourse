import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class AdminSectionLink extends BaseSectionLink {
  get name() {
    return "my-messages";
  }

  get route() {
    return "userPrivateMessages.user";
  }

  get model() {
    return this.currentUser;
  }

  get title() {
    return i18n("sidebar.sections.community.links.my_messages.content");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get shouldDisplay() {
    return !!this.currentUser?.can_send_private_messages;
  }

  get currentWhen() {
    return "userPrivateMessages";
  }
}
