import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Controller from "@ember/controller";
import PenaltyController from "admin/mixins/penalty-controller";

export default Controller.extend(PenaltyController, {
  suspendUntil: null,
  suspending: false,

  onShow() {
    this.resetModal();
    this.setProperties({ suspendUntil: null, suspending: false });
  },

  @discourseComputed("suspendUntil", "reason", "suspending")
  submitDisabled(suspendUntil, reason, suspending) {
    return suspending || isEmpty(suspendUntil) || !reason || reason.length < 1;
  },

  actions: {
    suspend() {
      if (this.submitDisabled) {
        return;
      }

      this.set("suspending", true);

      this.penalize(() => {
        return this.user.suspend({
          suspend_until: this.suspendUntil,
          reason: this.reason,
          message: this.message,
          post_id: this.postId,
          post_action: this.postAction,
          post_edit: this.postEdit
        });
      }).finally(() => this.set("suspending", false));
    }
  }
});
