import { alias } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action, get } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default class AdminMergeUsersPromptController extends Controller.extend(
  ModalFunctionality
) {
  @controller adminUserIndex;

  @alias("model.username") username;

  onShow() {
    this.set("targetUsername", null);
  }

  @discourseComputed("username", "targetUsername")
  mergeDisabled(username, targetUsername) {
    return !targetUsername || username === targetUsername;
  }

  @discourseComputed("username")
  mergeButtonText(username) {
    return I18n.t(`admin.user.merge.confirmation.transfer_and_delete`, {
      username,
    });
  }

  @action
  showConfirmation() {
    this.send("closeModal");
    this.adminUserIndex.send("showMergeConfirmation", this.targetUsername);
  }

  @action
  close() {
    this.send("closeModal");
  }

  @action
  updateUsername(selected) {
    this.set("targetUsername", get(selected, "firstObject"));
  }
}
