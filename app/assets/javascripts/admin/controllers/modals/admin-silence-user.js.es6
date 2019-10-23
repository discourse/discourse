import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import PenaltyController from "admin/mixins/penalty-controller";

export default Controller.extend(PenaltyController, {
  silenceUntil: null,
  silencing: false,

  onShow() {
    this.resetModal();
    this.setProperties({ silenceUntil: null, silencing: false });
  },

  @computed("silenceUntil", "reason", "silencing")
  submitDisabled(silenceUntil, reason, silencing) {
    return (
      silencing || Ember.isEmpty(silenceUntil) || !reason || reason.length < 1
    );
  },

  actions: {
    silence() {
      if (this.submitDisabled) {
        return;
      }

      this.set("silencing", true);
      this.penalize(() => {
        return this.user.silence({
          silenced_till: this.silenceUntil,
          reason: this.reason,
          message: this.message,
          post_id: this.postId,
          post_action: this.postAction,
          post_edit: this.postEdit
        });
      }).finally(() => this.set("silencing", false));
    }
  }
});
