import Controller, { inject as controller } from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
  adminUserIndex: controller(),
  username: alias("model.username"),

  onShow() {
    this.set("targetUsername", null);
  },

  @discourseComputed("username", "targetUsername")
  mergeDisabled(username, targetUsername) {
    return !targetUsername || username === targetUsername;
  },

  @action
  showConfirmation() {
    this.send("closeModal");
    this.adminUserIndex.send("showMergeConfirmation", this.targetUsername);
  },

  @action
  close() {
    this.send("closeModal");
  }
});
