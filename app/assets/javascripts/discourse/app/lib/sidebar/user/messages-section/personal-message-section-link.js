import MessageSectionLink from "discourse/lib/sidebar/user/messages-section/message-section-link";
import { i18n } from "discourse-i18n";

export default class PersonalMessageSectionLink extends MessageSectionLink {
  routeNames = new Set([
    "userPrivateMessages.user",
    "userPrivateMessages.user.index",
    "userPrivateMessages.user.unread",
    "userPrivateMessages.user.sent",
    "userPrivateMessages.user.new",
    "userPrivateMessages.user.archive",
  ]);

  get name() {
    return `personal-messages-${this.type}`;
  }

  get class() {
    return `personal-messages`;
  }

  get route() {
    if (this._isInbox) {
      return "userPrivateMessages.user.index";
    } else {
      return `userPrivateMessages.user.${this.type}`;
    }
  }

  get currentWhen() {
    if (this._isInbox) {
      return [...this.routeNames].join(" ");
    }
  }

  get model() {
    return this.currentUser;
  }

  get text() {
    if (this.count > 0) {
      return i18n(`sidebar.sections.messages.links.${this.type}_with_count`, {
        count: this.count,
      });
    } else {
      return i18n(`sidebar.sections.messages.links.${this.type}`);
    }
  }

  pageChanged({ currentRouteName, privateMessageTopic }) {
    if (this._isInbox) {
      return;
    }

    if (privateMessageTopic?.allowedGroups?.length === 0) {
      this.setDisplayState = true;
      return;
    }

    this.setDisplayState = this.routeNames.has(currentRouteName);
  }
}
