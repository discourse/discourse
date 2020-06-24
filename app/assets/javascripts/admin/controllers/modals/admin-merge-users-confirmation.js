import I18n from "I18n";
import Controller, { inject as controller } from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
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
      targetUsername
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
  }
});
