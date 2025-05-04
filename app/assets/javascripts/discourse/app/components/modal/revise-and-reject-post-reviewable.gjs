import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DTextarea from "discourse/components/d-textarea";
import ReviewableQueuedPost from "discourse/components/reviewable-queued-post";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

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

  <template>
    <DModal
      class="revise-and-reject-reviewable"
      @closeModal={{@closeModal}}
      @title={{i18n "review.revise_and_reject_post.title"}}
    >
      <:body>
        <div class="revise-and-reject-reviewable__queued-post">
          <ReviewableQueuedPost @reviewable={{@model.reviewable}} @tagName="" />
        </div>

        <div class="control-group">
          <label class="control-label" for="reason">{{i18n
              "review.revise_and_reject_post.reason"
            }}</label>
          <ComboBox
            @name="reason"
            @content={{this.configuredReasons}}
            @value={{this.reason}}
            @onChange={{fn (mut this.reason)}}
            class="revise-and-reject-reviewable__reason"
          />
        </div>

        {{#if this.showCustomReason}}
          <div class="control-group">
            <label class="control-label" for="custom_reason">{{i18n
                "review.revise_and_reject_post.custom_reason"
              }}</label>
            <Input
              name="custom_reason"
              class="revise-and-reject-reviewable__custom-reason"
              @type="text"
              @value={{this.customReason}}
            />
          </div>
        {{/if}}

        <div class="control-group">
          <label class="control-label" for="feedback">{{i18n
              "review.revise_and_reject_post.feedback"
            }}
            <span class="revise-and-reject-reviewable__optional">({{i18n
                "review.revise_and_reject_post.optional"
              }})</span>
          </label>
          <DTextarea
            @name="feedback"
            @value={{this.feedback}}
            @onChange={{fn (mut this.feedback)}}
            class="revise-and-reject-reviewable__feedback"
          />
        </div>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.rejectAndSendPM}}
          @disabled={{this.sendPMDisabled}}
          @label="review.revise_and_reject_post.send_pm"
        />
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
