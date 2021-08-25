import EmberObject from "@ember/object";
import {
  ARCHIVE_FILTER,
  INBOX_FILTER,
  NEW_FILTER,
  UNREAD_FILTER,
} from "discourse/routes/build-private-messages-route";
import { NotificationLevels } from "discourse/lib/notification-levels";

// See private_message_topic_tracking_state.rb for documentation
const PrivateMessageTopicTrackingState = EmberObject.extend({
  CHANNEL_PREFIX: "/private-message-topic-tracking-state",

  inbox: null,
  filter: null,
  activeGroup: null,

  startTracking(data) {
    this.states = new Map();
    this.newIncoming = [];
    this._loadStates(data);
    this.establishChannels();
  },

  establishChannels() {
    this.messageBus.subscribe(
      this._userChannel(this.user.id),
      this._processMessage.bind(this)
    );

    this.user.groupsWithMessages?.forEach((group) => {
      this.messageBus.subscribe(
        this._groupChannel(group.id),
        this._processMessage.bind(this)
      );
    });
  },

  stopTracking() {
    this.messageBus.unsubscribe(this._userChannel(this.user.id));

    this.user.groupsWithMessages?.forEach((group) => {
      this.messageBus.unsubscribe(this._groupChannel(group.id));
    });
  },

  lookupCount(type) {
    const typeFilterFn = type === "new" ? this._isNew : this._isUnread;
    let filterFn;

    if (this.inbox === "user") {
      filterFn = this._isPersonal.bind(this);
    } else if (this.inbox === "group") {
      filterFn = this._isGroup.bind(this);
    }

    return Array.from(this.states.values()).filter((topic) => {
      return typeFilterFn(topic) && (!filterFn || filterFn(topic));
    }).length;
  },

  trackIncoming(inbox, filter, group) {
    this.setProperties({ inbox, filter, activeGroup: group });
  },

  resetTracking() {
    if (this.inbox) {
      this.set("newIncoming", []);
    }
  },

  _userChannel(userId) {
    return `${this.CHANNEL_PREFIX}/user/${userId}`;
  },

  _groupChannel(groupId) {
    return `${this.CHANNEL_PREFIX}/group/${groupId}`;
  },

  _isNew(topic) {
    return (
      !topic.last_read_post_number &&
      ((topic.notification_level !== 0 && !topic.notification_level) ||
        topic.notification_level >= NotificationLevels.TRACKING) &&
      !topic.is_seen
    );
  },

  _isUnread(topic) {
    return (
      topic.last_read_post_number &&
      topic.last_read_post_number < topic.highest_post_number &&
      topic.notification_level >= NotificationLevels.TRACKING
    );
  },

  _isPersonal(topic) {
    const groups = this.user.groups;

    if (groups.length === 0) {
      return true;
    }

    return !groups.some((group) => {
      return topic.group_ids?.includes(group.id);
    });
  },

  _isGroup(topic) {
    return this.user.groups.some((group) => {
      return (
        group.name === this.activeGroup.name &&
        topic.group_ids?.includes(group.id)
      );
    });
  },

  _processMessage(message) {
    switch (message.message_type) {
      case "new_topic":
        this._modifyState(message.topic_id, message.payload);

        if (
          [NEW_FILTER, INBOX_FILTER].includes(this.filter) &&
          this._shouldDisplayMessageForInbox(message)
        ) {
          this._notifyIncoming(message.topic_id);
        }

        break;
      case "unread":
        this._modifyState(message.topic_id, message.payload);

        if (
          [UNREAD_FILTER, INBOX_FILTER].includes(this.filter) &&
          this._shouldDisplayMessageForInbox(message)
        ) {
          this._notifyIncoming(message.topic_id);
        }

        break;
      case "archive":
        if (
          [INBOX_FILTER, ARCHIVE_FILTER].includes(this.filter) &&
          ["user", "all"].includes(this.inbox)
        ) {
          this._notifyIncoming(message.topic_id);
        }
        break;
      case "group_archive":
        if (
          [INBOX_FILTER, ARCHIVE_FILTER].includes(this.filter) &&
          (this.inbox === "all" || this._displayMessageForGroupInbox(message))
        ) {
          this._notifyIncoming(message.topic_id);
        }
    }
  },

  _displayMessageForGroupInbox(message) {
    return (
      this.inbox === "group" &&
      message.payload.group_ids.includes(this.activeGroup.id)
    );
  },

  _shouldDisplayMessageForInbox(message) {
    return (
      this.inbox === "all" ||
      this._displayMessageForGroupInbox(message) ||
      (this.inbox === "user" &&
        (message.payload.group_ids.length === 0 ||
          this.currentUser.groups.filter((group) => {
            return message.payload.group_ids.includes(group.id);
          }).length === 0))
    );
  },

  _notifyIncoming(topicId) {
    if (this.newIncoming.indexOf(topicId) === -1) {
      this.newIncoming.pushObject(topicId);
    }
  },

  _loadStates(data) {
    (data || []).forEach((topic) => {
      this._modifyState(topic.topic_id, topic);
    });
  },

  _modifyState(topicId, data) {
    this.states.set(topicId, data);
  },
});

export default PrivateMessageTopicTrackingState;
