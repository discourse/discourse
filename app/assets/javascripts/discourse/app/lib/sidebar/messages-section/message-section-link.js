import { tracked } from "@glimmer/tracking";

import { INBOX } from "discourse/components/sidebar/messages-section";

export default class MessageSectionLink {
  @tracked shouldDisplay = this._isInbox;

  constructor({ group, currentUser, type }) {
    this.group = group;
    this.currentUser = currentUser;
    this.type = type;
  }

  set setDisplayState(value) {
    this.shouldDisplay = value;
  }

  get inboxFilter() {
    throw "not implemented";
  }

  expand() {
    if (this._isInbox) {
      return;
    }

    this.setDisplayState = true;
  }

  collapse() {
    if (this._isInbox) {
      return;
    }

    this.setDisplayState = false;
  }

  // eslint-disable-next-line no-unused-vars
  pageChanged({ currentRouteName, currentRouteParams, privateMessageTopic }) {
    throw "not implemented";
  }

  get _isInbox() {
    return this.type === INBOX;
  }
}
