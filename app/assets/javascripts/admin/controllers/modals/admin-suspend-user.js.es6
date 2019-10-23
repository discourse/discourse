import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import PenaltyController from "admin/mixins/penalty-controller";

export default Controller.extend(PenaltyController, {
  suspendUntil: null,
  suspending: false,

  onShow() {
    this.resetModal();
    this.setProperties({ suspendUntil: null, suspending: false });
  },

  @computed("suspendUntil", "reason", "suspending")
  submitDisabled(suspendUntil, reason, suspending) {
    return (
      suspending || Ember.isEmpty(suspendUntil) || !reason || reason.length < 1
    );
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
