import {
  CLOSED,
  COMPOSER_TYPE,
  EDITING,
  KEEP_ALIVE_DURATION_SECONDS,
  REPLYING,
} from "discourse/plugins/discourse-presence/discourse/lib/presence";
import { cancel, throttle } from "@ember/runloop";
import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import { gt, readOnly } from "@ember/object/computed";
import Component from "@ember/component";
import { inject as service } from "@ember/service";

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

  isReply: readOnly("model.replyingToTopic"),
  isEdit: readOnly("model.editingPost"),

  @on("didInsertElement")
  subscribe() {
    this.presenceManager.subscribe(this.get("model.topic.id"), COMPOSER_TYPE);
  },

  @discourseComputed(
    "model.post.id",
    "editingUsers.@each.last_seen",
    "users.@each.last_seen",
    "isReply",
    "isEdit"
  )
  presenceUsers(postId, editingUsers, users, isReply, isEdit) {
    if (isEdit) {
      return editingUsers.filterBy("post_id", postId);
    } else if (isReply) {
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
    if ((!this.isReply && !this.isEdit) || !this.get("model.composerOpened")) {
      return;
    }

    let data = {
      topicId: this.get("model.topic.id"),
      state: this.isEdit ? EDITING : REPLYING,
      whisper: this.get("model.whisper"),
      postId: this.get("model.post.id"),
      presenceStaffOnly: this.get("model._presenceStaffOnly"),
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
  },
});
