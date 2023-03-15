import { alias } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default class AdminDeletePostsConfirmationController extends Controller.extend(
  ModalFunctionality
) {
  @controller adminUserIndex;

  @alias("model.username") username;

  @alias("model.post_count") postCount;

  onShow() {
    this.set("value", null);
  }

  @discourseComputed("username", "postCount")
  text(username, postCount) {
    return I18n.t(`admin.user.delete_posts.confirmation.text`, {
      username,
      postCount,
    });
  }

  @discourseComputed("username")
  deleteButtonText(username) {
    return I18n.t(`admin.user.delete_posts.confirmation.delete`, {
      username,
    });
  }

  @discourseComputed("value", "text")
  deleteDisabled(value, text) {
    return !value || text !== value;
  }

  @action
  confirm() {
    this.adminUserIndex.send("deleteAllPosts");
  }

  @action
  close() {
    this.send("closeModal");
  }
}
