// Subscribes to user events on the message bus
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import {
  ARCHIVE_FILTER,
  INBOX_FILTER,
  NEW_FILTER,
  UNREAD_FILTER,
} from "discourse/routes/build-private-messages-route";

const CHANNEL_PREFIX = "/private-message-topic-tracking-state";

class SubscribeUserPmTopicsInit {
  @service currentUser;
  @service messageBus;
  @service store;
  @service appEvents;
  @service siteSettings;
  @service site;
  @service router;

  constructor(owner) {
    setOwner(this, owner);

    if (!this.currentUser) {
      return;
    }

    this.messageBus.subscribe(this.userChannel(), this._processMessage);

    this.currentUser.groupsWithMessages?.forEach((group) => {
      this.messageBus.subscribe(
        this.groupChannel(group.id),
        this._processMessage
      );
    });
  }

  teardown() {
    if (!this.currentUser) {
      return;
    }

    this.messageBus.unsubscribe(this.userChannel(), this._processMessage);

    this.messageBus.unsubscribe(this.groupChannel("*"), this._processMessage);
  }

  userChannel() {
    return `${CHANNEL_PREFIX}/user/${this.currentUser.id}`;
  }

  groupChannel(groupId) {
    return `${CHANNEL_PREFIX}/group/${groupId}`;
  }

  @bind
  _processMessage(message) {
    switch (message.message_type) {
      case "new_topic":
        if (message.payload.created_by_user_id !== this.currentUser.id) {
          this._modifyState(message.topic_id, message.payload);
          if (
            [NEW_FILTER, INBOX_FILTER].includes(this.filter) &&
            this._shouldDisplayMessageForInbox(message)
          ) {
            this._notifyIncoming(message.topic_id);
          }
        }

        break;
      case "read":
        this._modifyState(message.topic_id, message.payload);

        break;
      case "unread":
        // Note: At some point we may want to make the same performance optimisation
        // here as we did with the other topic tracking state, where we only send
        // one 'unread' update to all users, not a more accurate unread update to
        // each individual user with their own read state. In this case, we need to
        // ignore unread updates which are triggered by the current user.
        //
        // cf. f6c852bf8e7f4dea519425ba87a114f22f52a8f4
        this._modifyState(message.topic_id, message.payload);

        if (
          [UNREAD_FILTER, INBOX_FILTER].includes(this.filter) &&
          this._shouldDisplayMessageForInbox(message)
        ) {
          this._notifyIncoming(message.topic_id);
        }

        break;
      case "group_archive":
        if (
          [INBOX_FILTER, ARCHIVE_FILTER].includes(this.filter) &&
          (!message.payload.acting_user_id ||
            message.payload.acting_user_id !== this.currentUser.id) &&
          this._displayMessageForGroupInbox(message)
        ) {
          this._notifyIncoming(message.topic_id);
        }

        break;
    }
  }
}

export default {
  after: "message-bus",
  initialize(owner) {
    this.instance = new SubscribeUserPmTopicsInit(owner);
  },
  teardown() {
    this.instance.teardown();
    this.instance = null;
  },
};
