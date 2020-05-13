import EmberObject from "@ember/object";
import { cancel, later } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

// The durations chosen here determines the accuracy of the presence feature and
// is tied closely with the server side implementation. Decreasing the duration
// to increase the accuracy will come at the expense of having to more network
// calls to publish the client's state.
//
// Logic walk through of our heuristic implementation:
// - When client A is typing, a message is published every KEEP_ALIVE_DURATION_SECONDS.
// - Client B receives the message and stores each user in an array and marks
//   the user with a client-side timestamp of when the user was seen.
// - If client A continues to type, client B will continue to receive messages to
//   update the client-side timestamp of when client A was last seen.
// - If client A disconnects or becomes inactive, the state of client A will be
//   cleaned up on client B by a scheduler that runs every TIMER_INTERVAL_MILLISECONDS
export const KEEP_ALIVE_DURATION_SECONDS = 10;
const BUFFER_DURATION_SECONDS = KEEP_ALIVE_DURATION_SECONDS + 2;

const MESSAGE_BUS_LAST_ID = 0;
const TIMER_INTERVAL_MILLISECONDS = 2000;

export const REPLYING = "replying";
export const EDITING = "editing";
export const CLOSED = "closed";

export const TOPIC_TYPE = "topic";
export const COMPOSER_TYPE = "composer";

const Presence = EmberObject.extend({
  users: null,
  editingUsers: null,
  subscribers: null,
  topicId: null,
  currentUser: null,
  messageBus: null,
  siteSettings: null,

  init() {
    this._super(...arguments);

    this.setProperties({
      users: [],
      editingUsers: [],
      subscribers: new Set()
    });
  },

  subscribe(type) {
    if (this.subscribers.size === 0) {
      this.messageBus.subscribe(
        this.channel,
        message => {
          const { user, state } = message;
          if (this.get("currentUser.id") === user.id) return;

          switch (state) {
            case REPLYING:
              this._appendUser(this.users, user);
              break;
            case EDITING:
              this._appendUser(this.editingUsers, user, {
                post_id: parseInt(message.post_id, 10)
              });
              break;
            case CLOSED:
              this._removeUser(user);
              break;
          }
        },
        MESSAGE_BUS_LAST_ID
      );
    }

    this.subscribers.add(type);
  },

  unsubscribe(type) {
    this.subscribers.delete(type);
    const noSubscribers = this.subscribers.size === 0;

    if (noSubscribers) {
      this.messageBus.unsubscribe(this.channel);
      this._stopTimer();

      this.setProperties({
        users: [],
        editingUsers: []
      });
    }

    return noSubscribers;
  },

  @discourseComputed("topicId")
  channel(topicId) {
    return `/presence/${topicId}`;
  },

  publish(state, whisper, postId, staffOnly) {
    if (this.get("currentUser.hide_profile_and_presence")) return;

    const data = {
      state,
      topic_id: this.topicId
    };

    if (whisper) {
      data.is_whisper = true;
    }

    if (postId && state === EDITING) {
      data.post_id = postId;
    }

    if (staffOnly) {
      data.staff_only = true;
    }

    return ajax("/presence/publish", {
      type: "POST",
      data
    });
  },

  _removeUser(user) {
    [this.users, this.editingUsers].forEach(users => {
      const existingUser = users.findBy("id", user.id);
      if (existingUser) users.removeObject(existingUser);
    });
  },

  _cleanUpUsers() {
    [this.users, this.editingUsers].forEach(users => {
      const staleUsers = [];

      users.forEach(user => {
        if (user.last_seen <= Date.now() - BUFFER_DURATION_SECONDS * 1000) {
          staleUsers.push(user);
        }
      });

      users.removeObjects(staleUsers);
    });

    return this.users.length === 0 && this.editingUsers.length === 0;
  },

  _appendUser(users, user, attrs) {
    let existingUser;
    let usersLength = 0;

    users.forEach(u => {
      if (u.id === user.id) {
        existingUser = u;
      }

      if (attrs && attrs.post_id) {
        if (u.post_id === attrs.post_id) usersLength++;
      } else {
        usersLength++;
      }
    });

    const props = attrs || {};
    props.last_seen = Date.now();

    if (existingUser) {
      existingUser.setProperties(props);
    } else {
      const limit = this.get("siteSettings.presence_max_users_shown");

      if (usersLength < limit) {
        users.pushObject(EmberObject.create(Object.assign(user, props)));
      }
    }

    this._startTimer(() => {
      this._cleanUpUsers();
    });
  },

  _scheduleTimer(callback) {
    return later(
      this,
      () => {
        const stop = callback();

        if (!stop) {
          this.set("_timer", this._scheduleTimer(callback));
        }
      },
      TIMER_INTERVAL_MILLISECONDS
    );
  },

  _stopTimer() {
    cancel(this._timer);
  },

  _startTimer(callback) {
    if (!this._timer) {
      this.set("_timer", this._scheduleTimer(callback));
    }
  }
});

export default Presence;
