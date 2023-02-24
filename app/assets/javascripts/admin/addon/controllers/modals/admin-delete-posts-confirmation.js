import { inject as controller } from "@ember/controller";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Modal.extend({
  adminUserIndex: controller(),
  username: alias("model.username"),
  postCount: alias("model.post_count"),

  onShow() {
    this.set("value", null);
  },

  @discourseComputed("username", "postCount")
  text(username, postCount) {
    return I18n.t(`admin.user.delete_posts.confirmation.text`, {
      username,
      postCount,
    });
  },

  @discourseComputed("username")
  deleteButtonText(username) {
    return I18n.t(`admin.user.delete_posts.confirmation.delete`, {
      username,
    });
  },

  @discourseComputed("value", "text")
  deleteDisabled(value, text) {
    return !value || text !== value;
  },

  @action
  confirm() {
    this.adminUserIndex.send("deleteAllPosts");
  },

  @action
  close() {
    this.send("closeModal");
  },
});
