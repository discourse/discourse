import I18n from "I18n";

import { tracked } from "@glimmer/tracking";
import { capitalize } from "@ember/string";

import { INBOX } from "discourse/components/sidebar/messages-section";

export default class GroupMessageSectionLink {
  @tracked shouldDisplay = this._isInbox;

  routeNames = new Set([
    "userPrivateMessages.group",
    "userPrivateMessages.groupUnread",
    "userPrivateMessages.groupNew",
    "userPrivateMessages.groupArchive",
  ]);

  constructor({ group, type, currentUser, router }) {
    this.group = group;
    this.type = type;
    this.currentUser = currentUser;
    this.router = router;
  }

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
      return `userPrivateMessages.group${capitalize(this.type)}`;
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
    } else {
      return I18n.t(`sidebar.sections.messages.links.${this.type}`);
    }
  }

  collapse() {
    if (this._isInbox) {
      return;
    }

    this.shouldDisplay = false;
  }

  pageChanged(currentRouteName, currentRouteParams) {
    if (this._isInbox) {
      return;
    }

    this.shouldDisplay =
      this.routeNames.has(currentRouteName) &&
      currentRouteParams.name.toLowerCase() === this.group.name.toLowerCase();
  }

  get _isInbox() {
    return this.type === INBOX;
  }
}
