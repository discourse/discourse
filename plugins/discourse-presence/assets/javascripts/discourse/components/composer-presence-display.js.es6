import { once } from "@ember/runloop";
import { debounce } from "@ember/runloop";
import { cancel } from "@ember/runloop";
import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";
import {
  default as computed,
  observes,
  on
} from "ember-addons/ember-computed-decorators";

export const keepAliveDuration = 10000;
export const bufferTime = 3000;

export default Component.extend({
  // Passed in variables
  action: null,
  post: null,
  topic: null,
  reply: null,
  title: null,

  // Internal variables
  previousState: null,
  currentState: null,
  presenceUsers: null,
  channel: null,

  @on("didInsertElement")
  composerOpened() {
    this._lastPublish = new Date();
    once(this, "updateState");
  },

  @observes("action", "post.id", "topic.id")
  composerStateChanged() {
    once(this, "updateState");
  },

  @observes("reply", "title")
  typing() {
    if (new Date() - this._lastPublish > keepAliveDuration) {
      this.publish({ current: this.currentState });
    }
  },

  @on("willDestroyElement")
  composerClosing() {
    this.publish({ previous: this.currentState });
    cancel(this._pingTimer);
    cancel(this._clearTimer);
  },

  updateState() {
    let state = null;
    const action = this.action;

    if (action === "reply" || action === "edit") {
      state = { action };
      if (action === "reply") state.topic_id = this.get("topic.id");
      if (action === "edit") state.post_id = this.get("post.id");
    }

    this.set("previousState", this.currentState);
    this.set("currentState", state);
  },

  @observes("currentState")
  currentStateChanged() {
    if (this.channel) {
      this.messageBus.unsubscribe(this.channel);
      this.set("channel", null);
    }

    this.clear();

    if (!["reply", "edit"].includes(this.action)) {
      return;
    }

    this.publish({
      response_needed: true,
      previous: this.previousState,
      current: this.currentState
    }).then(r => {
      if (this.isDestroyed) {
        return;
      }
      this.set("presenceUsers", r.users);
      this.set("channel", r.messagebus_channel);

      if (!r.messagebus_channel) {
        return;
      }

      this.messageBus.subscribe(
        r.messagebus_channel,
        message => {
          if (!this.isDestroyed) this.set("presenceUsers", message.users);
          this._clearTimer = debounce(
            this,
            "clear",
            keepAliveDuration + bufferTime
          );
        },
        r.messagebus_id
      );
    });
  },

  clear() {
    if (!this.isDestroyed) this.set("presenceUsers", []);
  },

  publish(data) {
    this._lastPublish = new Date();

    // Don't publish presence if disabled
    if (this.currentUser.hide_profile_and_presence) {
      return Ember.RSVP.Promise.resolve();
    }

    return ajax("/presence/publish", { type: "POST", data });
  },

  @computed("presenceUsers", "currentUser.id")
  users(users, currentUserId) {
    return (users || []).filter(user => user.id !== currentUserId);
  },

  isReply: Ember.computed.equal("action", "reply"),
  shouldDisplay: Ember.computed.gt("users.length", 0)
});
