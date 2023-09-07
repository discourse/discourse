import Component from "@glimmer/component";
import { isEmpty } from "@ember/utils";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

const OTHER_REASON = "Other...";

export default class ReviseAndRejectPostReviewable extends Component {
  @service siteSettings;

  @tracked reason = null;
  @tracked customReason = null;
  @tracked feedback = null;
  @tracked submitting = false;

  get configuredReasons() {
    return this.siteSettings.reviewable_revision_reasons
      .split("|")
      .concat([OTHER_REASON]);
  }

  get showCustomReason() {
    return this.reason === OTHER_REASON;
  }

  get sendPMDisabled() {
    return (
      isEmpty(this.reason) ||
      (this.reason === "Other" && isEmpty(this.customReason)) ||
      this.submitting
    );
  }

  @action
  rejectAndSendPM() {
    this.submitting = true;
    this.args.model
      .performConfirmed(this.args.model.action, {
        revise_reason: this.reason,
        revise_custom_reason: this.customReason,
        revise_feedback: this.feedback,
      })
      .then(() => {
        this.submitting = false;
        this.args.closeModal();
      })
      .finally(() => {
        this.submitting = false;
      });
  }
}
