import Controller from "@ember/controller";
import PenaltyController from "admin/mixins/penalty-controller";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { additionalTimeframeOptions } from "discourse/lib/time-shortcut";

export default Controller.extend(PenaltyController, {
  suspendUntil: null,
  suspending: false,
  userTimezone: null,

  onShow() {
    this.resetModal();
    this.setProperties({
      suspendUntil: null,
      suspending: false,
      userTimezone: this.currentUser.resolvedTimezone(this.currentUser),
    });
  },

  @discourseComputed("suspendUntil", "reason", "suspending")
  submitDisabled(suspendUntil, reason, suspending) {
    return suspending || isEmpty(suspendUntil) || !reason || reason.length < 1;
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
          post_edit: this.postEdit,
        });
      }).finally(() => this.set("suspending", false));
    },
  },
});
