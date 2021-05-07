import Controller from "@ember/controller";
import PenaltyController from "admin/mixins/penalty-controller";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { additionalTimeframeOptions } from "discourse/lib/time-shortcut";

export default Controller.extend(PenaltyController, {
  silenceUntil: null,
  silencing: false,
  userTimezone: null,

  onShow() {
    this.resetModal();
    this.setProperties({
      silenceUntil: null,
      silencing: false,
      userTimezone: this.currentUser.resolvedTimezone(this.currentUser),
    });
  },

  @discourseComputed("silenceUntil", "reason", "silencing")
  submitDisabled(silenceUntil, reason, silencing) {
    return silencing || isEmpty(silenceUntil) || !reason || reason.length < 1;
  },

  @discourseComputed("userTimezone")
  customTimeframeOptions(userTimezone) {
    const options = additionalTimeframeOptions(userTimezone);
    return [
      options.twoWeeks(),
      options.twoMonths(),
      options.threeMonths(),
      options.fourMonths(),
      options.sixMonths(),
      options.oneYear(),
      options.forever(),
    ];
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
          post_edit: this.postEdit,
        });
      }).finally(() => this.set("silencing", false));
    },
  },
});
