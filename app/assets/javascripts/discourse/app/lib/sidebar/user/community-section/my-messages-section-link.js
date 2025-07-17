import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class MyMessagesSectionLink extends BaseSectionLink {
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
    return i18n("sidebar.sections.community.links.my_messages.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overridenName
        .toLowerCase()
        .replace(" ", "_")}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get showCount() {
    return !this.currentUser?.sidebarShowCountOfNewItems;
  }

  get badgeText() {
    if (!this.showCount) {
      return;
    }

    if (this.currentUser.new_new_view_enabled) {
      return "0";
    } else {
      return i18n("sidebar.sections.community.links.my_messages.content");
    }
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (!this.showCount) {
      return "circle";
    }
  }

  get shouldDisplay() {
    return this.currentUser?.can_send_private_messages;
  }

  get currentWhen() {
    return "userPrivateMessages";
  }
}
