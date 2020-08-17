import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

// Modal that displays confirmation text when user deletes a topic
// The modal will display only if the topic exceeds a certain amount of views
export default Controller.extend(ModalFunctionality, {
  topicController: inject("topic"),
  deleting: false,

  @discourseComputed("deleting")
  buttonDisabled(deleting) {
    return !!deleting;
  },

  actions: {
    deleteTopic() {
      this.set("deleting", true);

      this.topicController.model
        .destroy(this.currentUser)
        .then(() => {
          this.send("closeModal");
          this.setProperties({ deleting: false });
        })
        .catch(() =>
          this.flash(I18n.t("post.controls.delete_topic_error"), "alert-error")
        )
        .finally(() => this.set("deleting", false));

      return false;
    }
  }
});
