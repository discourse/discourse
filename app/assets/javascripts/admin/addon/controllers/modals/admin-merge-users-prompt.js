import { inject as controller } from "@ember/controller";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import { action, get } from "@ember/object";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Modal.extend({
  adminUserIndex: controller(),
  username: alias("model.username"),

  onShow() {
    this.set("targetUsername", null);
  },

  @discourseComputed("username", "targetUsername")
  mergeDisabled(username, targetUsername) {
    return !targetUsername || username === targetUsername;
  },

  @discourseComputed("username")
  mergeButtonText(username) {
    return I18n.t(`admin.user.merge.confirmation.transfer_and_delete`, {
      username,
    });
  },

  @action
  showConfirmation() {
    this.send("closeModal");
    this.adminUserIndex.send("showMergeConfirmation", this.targetUsername);
  },

  @action
  close() {
    this.send("closeModal");
  },

  @action
  updateUsername(selected) {
    this.set("targetUsername", get(selected, "firstObject"));
  },
});
