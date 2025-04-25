import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import TextField from "discourse/components/text-field";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class ScrubRejectedUserModal extends Component {
  @tracked isScrubbing = false;
  @tracked scrubReason = "";

  @action
  async confirmScrub() {
    this.isScrubbing = true;
    await this.args.model.confirmScrub(this.scrubReason);
    this.args.closeModal();
  }

  get scrubButtonDisabled() {
    return isEmpty(this.scrubReason);
  }

  <template>
    <DModal
      @bodyClass="scrub-rejected-user"
      class="admin-scrub-rejected-user-modal"
      @title={{i18n "review.user.scrub_record.confirm_title"}}
      @closeModal={{if this.isScrubbing null @closeModal}}
    >
      <:body>
        <p>{{i18n "review.user.scrub_record.confirm_body"}}</p>
        <label class="scrub-reason-title" for="scrub-reason">{{i18n
            "review.user.scrub_record.reason_title"
          }}</label>

        <TextField
          class="scrub-reason"
          id="scrub-reason"
          @placeholderKey="review.user.scrub_record.reason_placeholder"
          {{on "input" (withEventValue (fn (mut this.scrubReason)))}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn btn-danger"
          @action={{this.confirmScrub}}
          @isLoading={{this.isScrubbing}}
          @disabled={{this.scrubButtonDisabled}}
          @label="review.user.scrub_record.confirm_button"
        />
        <DButton
          class="btn btn-default"
          @action={{@closeModal}}
          @disabled={{this.isScrubbing}}
          @label="review.user.scrub_record.cancel_button"
        />
      </:footer>
    </DModal>
  </template>
}
