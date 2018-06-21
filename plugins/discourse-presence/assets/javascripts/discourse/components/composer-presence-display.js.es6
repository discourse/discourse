import { ajax } from "discourse/lib/ajax";
import {
  default as computed,
  observes,
  on
} from "ember-addons/ember-computed-decorators";

export const keepAliveDuration = 10000;
export const bufferTime = 3000;

export default Ember.Component.extend({
  composer: Ember.inject.controller(),

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
    Ember.run.once(this, "updateState");
  },

  @observes("action", "post.id", "topic.id")
  composerStateChanged() {
    Ember.run.once(this, "updateState");
  },

  @observes("reply", "title")
  typing() {
    if (new Date() - this._lastPublish > keepAliveDuration) {
      this.publish({ current: this.get("currentState") });
    }
  },

  @on("willDestroyElement")
  composerClosing() {
    this.publish({ previous: this.get("currentState") });
    Ember.run.cancel(this._pingTimer);
    Ember.run.cancel(this._clearTimer);
  },

  updateState() {
    let state = null;
    const action = this.get("action");

    if (action === "reply" || action === "edit") {
      state = { action };
      if (action === "reply") state.topic_id = this.get("topic.id");
      if (action === "edit") state.post_id = this.get("post.id");
    }

    this.set("previousState", this.get("currentState"));
    this.set("currentState", state);
  },

  @observes("currentState")
  currentStateChanged() {
    if (this.get("channel")) {
      this.messageBus.unsubscribe(this.get("channel"));
      this.set("channel", null);
    }

    this.clear();

    if (!["reply", "edit"].includes(this.get("action"))) {
      return;
    }

    this.publish({
      response_needed: true,
      previous: this.get("previousState"),
      current: this.get("currentState")
    }).then(r => {
      if (this.get("isDestroyed")) {
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
          if (!this.get("isDestroyed"))
            this.set("presenceUsers", message.users);
          this._clearTimer = Ember.run.debounce(
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
    if (!this.get("isDestroyed")) this.set("presenceUsers", []);
  },

  publish(data) {
    this._lastPublish = new Date();
    return ajax("/presence/publish", { type: "POST", data });
  },

  @computed("presenceUsers", "currentUser.id")
  users(users, currentUserId) {
    return (users || []).filter(user => user.id !== currentUserId);
  },

  isReply: Ember.computed.equal("action", "reply"),
  shouldDisplay: Ember.computed.gt("users.length", 0)
});
