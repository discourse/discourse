import Component from "@glimmer/component";
import { Input, Textarea } from "@ember/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
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
      @bodyClass="reject-reason-reviewable-modal__explain-reviewable"
      @closeModal={{@closeModal}}
      @title={{i18n "review.reject_reason.title"}}
      class="reject-reason-reviewable-modal"
    >
      <:body>
        <Textarea @value={{this.rejectReason}} />
        <div class="control-group">
          <label>
            <Input
              @type="checkbox"
              class="reject-reason-reviewable-modal__send_email--inline"
              @checked={{this.sendEmail}}
            />
            {{i18n "review.reject_reason.send_email"}}
          </label>
        </div>
      </:body>

      <:footer>
        <DButton
          @icon="trash-can"
          @action={{this.perform}}
          @label="admin.user.delete"
          class="btn-danger"
        />
        <DButton @action={{@closeModal}} @label="cancel" class="cancel" />
      </:footer>
    </DModal>
  </template>
}
