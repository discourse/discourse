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