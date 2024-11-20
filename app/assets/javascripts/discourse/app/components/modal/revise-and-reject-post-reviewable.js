import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const OTHER_REASON = "other_reason";

export default class ReviseAndRejectPostReviewable extends Component {
  @service siteSettings;

  @tracked reason;
  @tracked customReason;
  @tracked feedback;
  @tracked submitting = false;

  get configuredReasons() {
    const reasons = this.siteSettings.reviewable_revision_reasons
      .split("|")
      .filter(Boolean)
      .map((reason) => ({ id: reason, name: reason }))
      .concat([
        {
          id: OTHER_REASON,
          name: i18n("review.revise_and_reject_post.other_reason"),
        },
      ]);
    return reasons;
  }

  get showCustomReason() {
    return this.reason === OTHER_REASON;
  }

  get sendPMDisabled() {
    return (
      isEmpty(this.reason) ||
      (this.reason === OTHER_REASON && isEmpty(this.customReason)) ||
      this.submitting
    );
  }

  @action
  async rejectAndSendPM() {
    this.submitting = true;

    try {
      await this.args.model.performConfirmed(this.args.model.action, {
        revise_reason: this.reason,
        revise_custom_reason: this.customReason,
        revise_feedback: this.feedback,
      });
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.submitting = false;
    }
  }
}
