import I18n from "I18n";

import MessageSectionLink from "discourse/lib/sidebar/messages-section/message-section-link";

export default class PersonalMessageSectionLink extends MessageSectionLink {
  routeNames = new Set([
    "userPrivateMessages.index",
    "userPrivateMessages.unread",
    "userPrivateMessages.sent",
    "userPrivateMessages.new",
    "userPrivateMessages.archive",
  ]);

  get name() {
    return `personal-messages-${this.type}`;
  }

  get class() {
    return `personal-messages`;
  }

  get route() {
    if (this._isInbox) {
      return "userPrivateMessages.index";
    } else {
      return `userPrivateMessages.${this.type}`;
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
      return I18n.t(`sidebar.sections.messages.links.${this.type}_with_count`, {
        count: this.count,
      });
    } else {
      return I18n.t(`sidebar.sections.messages.links.${this.type}`);
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
