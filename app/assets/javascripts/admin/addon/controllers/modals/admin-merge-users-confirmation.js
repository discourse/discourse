import { inject as controller } from "@ember/controller";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Modal.extend({
  adminUserIndex: controller(),
  username: alias("model.username"),
  targetUsername: alias("model.targetUsername"),

  onShow() {
    this.set("value", null);
  },

  @discourseComputed("username", "targetUsername")
  text(username, targetUsername) {
    return I18n.t(`admin.user.merge.confirmation.text`, {
      username,
      targetUsername,
    });
  },

  @discourseComputed("username")
  mergeButtonText(username) {
    return I18n.t(`admin.user.merge.confirmation.transfer_and_delete`, {
      username,
    });
  },

  @discourseComputed("value", "text")
  mergeDisabled(value, text) {
    return !value || text !== value;
  },

  @action
  confirm() {
    this.adminUserIndex.send("merge", this.targetUsername);
    this.send("closeModal");
  },

  @action
  close() {
    this.send("closeModal");
  },
});
