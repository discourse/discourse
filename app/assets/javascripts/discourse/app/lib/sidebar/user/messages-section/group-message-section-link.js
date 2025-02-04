import MessageSectionLink from "discourse/lib/sidebar/user/messages-section/message-section-link";
import { i18n } from "discourse-i18n";

export default class GroupMessageSectionLink extends MessageSectionLink {
  routeNames = new Set([
    "userPrivateMessages.group",
    "userPrivateMessages.group.index",
    "userPrivateMessages.group.unread",
    "userPrivateMessages.group.new",
    "userPrivateMessages.group.archive",
  ]);

  get name() {
    return `group-messages-${this.type}`;
  }

  get class() {
    return this.group.name;
  }

  get route() {
    if (this._isInbox) {
      return "userPrivateMessages.group";
    } else {
      return `userPrivateMessages.group.${this.type}`;
    }
  }

  get currentWhen() {
    if (this._isInbox) {
      return [...this.routeNames].join(" ");
    }
  }

  get models() {
    return [this.currentUser, this.group.name];
  }

  get text() {
    if (this._isInbox) {
      return this.group.name;
    } else if (this.count > 0) {
      return i18n(`sidebar.sections.messages.links.${this.type}_with_count`, {
        count: this.count,
      });
    } else {
      return i18n(`sidebar.sections.messages.links.${this.type}`);
    }
  }

  pageChanged({
    currentRouteName,
    currentRouteParentParams,
    privateMessageTopic,
  }) {
    if (this._isInbox) {
      return;
    }

    if (
      privateMessageTopic?.allowedGroups?.some(
        (g) => g.name === this.group.name
      )
    ) {
      this.setDisplayState = true;
      return;
    }

    this.setDisplayState =
      this.routeNames.has(currentRouteName) &&
      currentRouteParentParams.name.toLowerCase() ===
        this.group.name.toLowerCase();
  }
}
