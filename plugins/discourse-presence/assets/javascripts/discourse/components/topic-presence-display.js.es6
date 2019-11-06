import { debounce } from "@ember/runloop";
import { cancel } from "@ember/runloop";
import Component from "@ember/component";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";
import {
  keepAliveDuration,
  bufferTime
} from "discourse/plugins/discourse-presence/discourse/components/composer-presence-display";

const MB_GET_LAST_MESSAGE = -2;

export default Component.extend({
  topicId: null,
  presenceUsers: null,

  clear() {
    if (!this.isDestroyed) this.set("presenceUsers", []);
  },

  @on("didInsertElement")
  _inserted() {
    this.clear();

    this.messageBus.subscribe(
      this.channel,
      message => {
        if (!this.isDestroyed) this.set("presenceUsers", message.users);
        this._clearTimer = debounce(
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
    cancel(this._clearTimer);
    this.messageBus.unsubscribe(this.channel);
  },

  @computed("topicId")
  channel(topicId) {
    return `/presence/topic/${topicId}`;
  },

  @computed("presenceUsers", "currentUser.{id,ignored_users}")
  users(users, currentUser) {
    const ignoredUsers = currentUser.ignored_users || [];
    return (users || []).filter(
      user =>
        user.id !== currentUser.id && !ignoredUsers.includes(user.username)
    );
  },

  shouldDisplay: Ember.computed.gt("users.length", 0)
});
