import Component from "@ember/component";
import { cancel } from "@ember/runloop";
import { equal, gt, readOnly } from "@ember/object/computed";
import discourseComputed, {
  observes,
  on
} from "discourse-common/utils/decorators";
import { REPLYING, CLOSED, EDITING } from "../lib/presence-manager";

export default Component.extend({
  // Passed in variables
  action: null,
  post: null,
  topic: null,
  reply: null,
  title: null,
  isWhispering: null,

  presenceManager: readOnly("topic.presenceManager"),
  users: readOnly("presenceManager.users"),
  editingUsers: readOnly("presenceManager.editingUsers"),
  isReply: equal("action", "reply"),

  @on("didInsertElement")
  subscribe() {
    this.presenceManager && this.presenceManager.subscribe();
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
    if (this.presenceManager) {
      const postId = this.get("post.id");

      this._throttle = this.presenceManager.throttlePublish(
        postId ? EDITING : REPLYING,
        this.whisper,
        postId
      );
    }
  },

  @observes("whisper")
  cancelThrottle() {
    this._cancelThrottle();
  },

  @observes("post.id")
  stopEditing() {
    if (this.presenceManager && !this.get("post.id")) {
      this.presenceManager.publish(CLOSED, this.whisper);
    }
  },

  @on("willDestroyElement")
  composerClosing() {
    if (this.presenceManager) {
      this._cancelThrottle();
      this.presenceManager.publish(CLOSED, this.whisper);
    }
  },

  _cancelThrottle() {
    cancel(this._throttle);
  }
});
