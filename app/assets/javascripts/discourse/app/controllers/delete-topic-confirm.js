import { inject as controller } from "@ember/controller";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

// Modal that displays confirmation text when user deletes a topic
// The modal will display only if the topic exceeds a certain amount of views
export default Modal.extend({
  topicController: controller("topic"),
  deletingTopic: false,

  @discourseComputed("deletingTopic")
  buttonTitle(deletingTopic) {
    return deletingTopic
      ? I18n.t("deleting")
      : I18n.t("post.controls.delete_topic_confirm_modal_yes");
  },

  onShow() {
    this.set("deletingTopic", false);
  },

  @action
  deleteTopic() {
    this.set("deletingTopic", true);

    this.topicController.model
      .destroy(this.currentUser)
      .then(() => this.send("closeModal"))
      .catch(() => {
        this.flash(I18n.t("post.controls.delete_topic_error"), "error");
        this.set("deletingTopic", false);
      });

    return false;
  },
});
