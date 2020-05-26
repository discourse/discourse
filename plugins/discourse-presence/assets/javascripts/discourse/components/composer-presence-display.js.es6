import Component from "@ember/component";
import { cancel, throttle } from "@ember/runloop";
import { equal, gt } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import discourseComputed, {
  observes,
  on
} from "discourse-common/utils/decorators";
import {
  REPLYING,
  CLOSED,
  EDITING,
  COMPOSER_TYPE,
  KEEP_ALIVE_DURATION_SECONDS
} from "discourse/plugins/discourse-presence/discourse/lib/presence";

import { REPLY, EDIT } from "discourse/models/composer";

export default Component.extend({
  // Passed in variables
  presenceManager: service(),

  @discourseComputed("model.topic.id")
  users(topicId) {
    return this.presenceManager.users(topicId);
  },

  @discourseComputed("model.topic.id")
  editingUsers(topicId) {
    return this.presenceManager.editingUsers(topicId);
  },

  isReply: equal("model.action", REPLY),

  @on("didInsertElement")
  subscribe() {
    this.presenceManager.subscribe(this.get("model.topic.id"), COMPOSER_TYPE);
  },

  @discourseComputed(
    "model.post.id",
    "editingUsers.@each.last_seen",
    "users.@each.last_seen",
    "model.action"
  )
  presenceUsers(postId, editingUsers, users, action) {
    if (action === EDIT) {
      return editingUsers.filterBy("post_id", postId);
    } else if (action === REPLY) {
      return users;
    }
    return [];
  },

  shouldDisplay: gt("presenceUsers.length", 0),

  @observes("model.reply", "model.title")
  typing() {
    throttle(this, this._typing, KEEP_ALIVE_DURATION_SECONDS * 1000);
  },

  _typing() {
    const action = this.get("model.action");

    if (
      (action !== REPLY && action !== EDIT) ||
      !this.get("model.composerOpened")
    ) {
      return;
    }

    let data = {
      topicId: this.get("model.topic.id"),
      state: action === EDIT ? EDITING : REPLYING,
      whisper: this.get("model.whisper"),
      postId: this.get("model.post.id"),
      presenceStaffOnly: this.get("model._presenceStaffOnly")
    };

    this._prevPublishData = data;

    this._throttle = this.presenceManager.publish(
      data.topicId,
      data.state,
      data.whisper,
      data.postId,
      data.presenceStaffOnly
    );
  },

  @observes("model.whisper")
  cancelThrottle() {
    this._cancelThrottle();
  },

  @observes("model.action", "model.topic.id")
  composerState() {
    if (this._prevPublishData) {
      this.presenceManager.publish(
        this._prevPublishData.topicId,
        CLOSED,
        this._prevPublishData.whisper,
        this._prevPublishData.postId
      );
      this._prevPublishData = null;
    }
  },

  @on("willDestroyElement")
  closeComposer() {
    this._cancelThrottle();
    this._prevPublishData = null;
    this.presenceManager.cleanUpPresence(COMPOSER_TYPE);
  },

  _cancelThrottle() {
    if (this._throttle) {
      cancel(this._throttle);
      this._throttle = null;
    }
  }
});
