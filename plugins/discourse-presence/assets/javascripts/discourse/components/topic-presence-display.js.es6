import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";
import {
  keepAliveDuration,
  bufferTime
} from "discourse/plugins/discourse-presence/discourse/components/composer-presence-display";

const MB_GET_LAST_MESSAGE = -2;

export default Ember.Component.extend({
  topicId: null,
  presenceUsers: null,

  clear() {
    if (!this.get("isDestroyed")) this.set("presenceUsers", []);
  },

  @on("didInsertElement")
  _inserted() {
    this.clear();

    this.messageBus.subscribe(
      this.get("channel"),
      message => {
        if (!this.get("isDestroyed")) this.set("presenceUsers", message.users);
        this._clearTimer = Ember.run.debounce(
          this,
          "clear",
          keepAliveDuration + bufferTime
        );
      },
      MB_GET_LAST_MESSAGE
    );
  },

  @on("willDestroyElement")
  _destroyed() {
    Ember.run.cancel(this._clearTimer);
    this.messageBus.unsubscribe(this.get("channel"));
  },

  @computed("topicId")
  channel(topicId) {
    return `/presence/topic/${topicId}`;
  },

  @computed("presenceUsers", "currentUser.id")
  users(users, currentUserId) {
    return (users || []).filter(user => user.id !== currentUserId);
  },

  shouldDisplay: Ember.computed.gt("users.length", 0)
});
