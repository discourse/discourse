import computed from "ember-addons/ember-computed-decorators";
import PenaltyController from "admin/mixins/penalty-controller";

export default Ember.Controller.extend(PenaltyController, {
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
      if (this.get("submitDisabled")) {
        return;
      }

      this.set("suspending", true);

      this.penalize(() => {
        return this.get("user").suspend({
          suspend_until: this.get("suspendUntil"),
          reason: this.get("reason"),
          message: this.get("message"),
          post_id: this.get("post.id"),
          post_action: this.get("postAction"),
          post_edit: this.get("postEdit")
        });
      }).finally(() => this.set("suspending", false));
    }
  }
});
