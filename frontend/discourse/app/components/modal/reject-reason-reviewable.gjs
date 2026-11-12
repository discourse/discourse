import Component from "@glimmer/component";
import { Input, Textarea } from "@ember/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class RejectReasonReviewableModal extends Component {
  rejectReason;
  sendEmail = false;

  @action
  async perform() {
    this.args.model.reviewable.setProperties({
      rejectReason: this.rejectReason,
      sendEmail: this.sendEmail,
    });
    this.args.closeModal();
    await this.args.model.performConfirmed(this.args.model.action);
  }

  <template>
    <DModal
      class="reject-reason-reviewable-modal"
      @bodyClass="reject-reason-reviewable-modal__explain-reviewable"
      @closeModal={{@closeModal}}
      @title={{i18n "review.reject_reason.title"}}
    >
      <:body>
        <Textarea @value={{this.rejectReason}} />
        <div class="control-group">
          <label>
            <Input
              class="reject-reason-reviewable-modal__send_email--inline"
              @checked={{this.sendEmail}}
              @type="checkbox"
            />
            {{i18n "review.reject_reason.send_email"}}
          </label>
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn-danger"
          @action={{this.perform}}
          @icon="trash-can"
          @label="admin.user.delete"
        />
        <DButton class="cancel" @action={{@closeModal}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
