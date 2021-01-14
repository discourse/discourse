import Controller, { inject as controller } from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

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
  },

  @action
  updateUsername(selected) {
    if (selected && selected.length > 0) {
      this.set("targetUsername", selected[0]);
    } else {
      this.set("targetUsername", null);
    }
  },
});
