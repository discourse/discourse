import Component from "@ember/component";
import { getOwner } from "@ember/application";
import { cancel } from "@ember/runloop";
import { equal, gt } from "@ember/object/computed";
import discourseComputed, {
  observes,
  on
} from "discourse-common/utils/decorators";
import {
  REPLYING,
  CLOSED,
  EDITING,
  COMPOSER_TYPE
} from "../lib/presence-manager";
import { REPLY, EDIT } from "discourse/models/composer";

export default Component.extend({
  // Passed in variables
  action: null,
  post: null,
  topic: null,
  reply: null,
  title: null,
  isWhispering: null,
  presenceManager: null,

  init() {
    this._super(...arguments);

    this.setProperties({
      presenceManager: getOwner(this).lookup("presence-manager:main")
    });
  },

  @discourseComputed("topic.id")
  users(topicId) {
    return this.presenceManager.users(topicId);
  },

  @discourseComputed("topic.id")
  editingUsers(topicId) {
    return this.presenceManager.editingUsers(topicId);
  },

  isReply: equal("action", "reply"),

  @on("didInsertElement")
  subscribe() {
    this.presenceManager.subscribe(this.get("topic.id"), COMPOSER_TYPE);
  },

  @discourseComputed(
    "post.id",
    "editingUsers.@each.last_seen",
    "users.@each.last_seen"
  )
  presenceUsers(postId, editingUsers, users) {
    if (postId) {
      return editingUsers.filterBy("post_id", postId);
    } else {
      return users;
    }
  },

  shouldDisplay: gt("presenceUsers.length", 0),

  @observes("reply", "title")
  typing() {
    const action = this.action;

    if (action !== REPLY && action !== EDIT) {
      return;
    }

    const postId = this.get("post.id");

    this._throttle = this.presenceManager.throttlePublish(
      this.get("topic.id"),
      action === EDIT ? EDITING : REPLYING,
      this.whisper,
      action === EDIT ? postId : undefined
    );
  },

  @observes("whisper")
  cancelThrottle() {
    this._cancelThrottle();
  },

  @observes("action", "topic.id")
  composerState() {
    if (!this.get("post.id")) {
      this.presenceManager.publish(this.get("topic.id"), CLOSED, this.whisper);
    }
  },

  @on("willDestroyElement")
  closeComposer() {
    this._cancelThrottle();
    this.presenceManager.cleanUpPresence(COMPOSER_TYPE);
  },

  _cancelThrottle() {
    if (this._throttle) cancel(this._throttle);
  }
});
