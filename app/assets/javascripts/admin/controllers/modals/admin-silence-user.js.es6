import computed from "ember-addons/ember-computed-decorators";
import PenaltyController from "admin/mixins/penalty-controller";

export default Ember.Controller.extend(PenaltyController, {
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
      if (this.get("submitDisabled")) {
        return;
      }

      this.set("silencing", true);
      this.penalize(() => {
        return this.get("user").silence({
          silenced_till: this.get("silenceUntil"),
          reason: this.get("reason"),
          message: this.get("message"),
          post_id: this.get("post.id"),
          post_action: this.get("postAction"),
          post_edit: this.get("postEdit")
        });
      }).finally(() => this.set("silencing", false));
    }
  }
});
