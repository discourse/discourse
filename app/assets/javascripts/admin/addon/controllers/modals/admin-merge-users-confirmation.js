import { alias } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default class AdminMergeUsersConfirmationController extends Controller.extend(
  ModalFunctionality
) {
  @controller adminUserIndex;

  @alias("model.username") username;

  @alias("model.targetUsername") targetUsername;

  onShow() {
    this.set("value", null);
  }

  @discourseComputed("username", "targetUsername")
  text(username, targetUsername) {
    return I18n.t(`admin.user.merge.confirmation.text`, {
      username,
      targetUsername,
    });
  }

  @discourseComputed("username")
  mergeButtonText(username) {
    return I18n.t(`admin.user.merge.confirmation.transfer_and_delete`, {
      username,
    });
  }

  @discourseComputed("value", "text")
  mergeDisabled(value, text) {
    return !value || text !== value;
  }

  @action
  confirm() {
    this.adminUserIndex.send("merge", this.targetUsername);
    this.send("closeModal");
  }

  @action
  close() {
    this.send("closeModal");
  }
}
