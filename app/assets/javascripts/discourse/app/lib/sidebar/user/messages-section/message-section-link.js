import { tracked } from "@glimmer/tracking";

import {
  INBOX,
  NEW,
  UNREAD,
} from "discourse/components/sidebar/user/messages-section";

export default class MessageSectionLink {
  @tracked shouldDisplay = this._isInbox;
  @tracked count = 0;

  constructor({ group, currentUser, type, pmTopicTrackingState }) {
    this.group = group;
    this.currentUser = currentUser;
    this.type = type;
    this.pmTopicTrackingState = pmTopicTrackingState;
  }

  refreshCount() {
    this._refreshCount();
  }

  _refreshCount() {
    if (this.shouldDisplay && this._shouldTrack) {
      this.count = this.pmTopicTrackingState.lookupCount(this.type, {
        inboxFilter: this.group ? "group" : "user",
        groupName: this.group?.name,
      });
    }
  }

  set setDisplayState(value) {
    const changed = this.shouldDisplay !== value;
    this.shouldDisplay = value;

    if (changed) {
      this._refreshCount();
    }
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

  get _shouldTrack() {
    return this.type === NEW || this.type === UNREAD;
  }

  get prefixType() {
    if (this._isInbox) {
      return "icon";
    }
  }

  get prefixValue() {
    if (this._isInbox) {
      return "inbox";
    }
  }
}
