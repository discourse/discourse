import I18n from "I18n";

import { tracked } from "@glimmer/tracking";
import { INBOX } from "discourse/components/sidebar/messages-section";

export default class PersonalMessageSectionLink {
  @tracked shouldDisplay = this._isInbox;

  routeNames = new Set([
    "userPrivateMessages.index",
    "userPrivateMessages.unread",
    "userPrivateMessages.sent",
    "userPrivateMessages.new",
    "userPrivateMessages.archive",
  ]);

  constructor({ currentUser, type, router }) {
    this.currentUser = currentUser;
    this.type = type;
    this.router = router;
  }

  get name() {
    return `personal-messages-${this.type}`;
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
    return I18n.t(`sidebar.sections.messages.links.${this.type}`);
  }

  collapse() {
    if (this._isInbox) {
      return;
    }

    this.shouldDisplay = false;
  }

  pageChanged(currentRouteName) {
    if (this._isInbox) {
      return;
    }

    this.shouldDisplay = this.routeNames.has(currentRouteName);
  }

  get _isInbox() {
    return this.type === INBOX;
  }
}
