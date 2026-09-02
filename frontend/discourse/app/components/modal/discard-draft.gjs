import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class DiscardDraftModal extends Component {
  @action
  async discardDraft() {
    await this.args.model.onDestroyDraft();
    this.args.closeModal();
  }

  @action
  async cancelDiscard() {
    await this.args.model.onCancelDiscard();
    this.args.closeModal();
  }

  <template>
    <DModal
      class="discard-draft-modal --stacked"
      @closeModal={{this.cancelDiscard}}
      @hideHeader={{true}}
    >
      <:body>
        <div aria-level="1" class="instructions" role="heading">
          {{i18n @model.confirmMessageKey}}
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn-danger discard-draft-modal__discard-btn"
          @action={{this.discardDraft}}
          @icon="trash-can"
          @label={{@model.discardButtonKey}}
        />
        <DButton
          class="btn-transparent discard-draft-modal__cancel-btn"
          @action={{this.cancelDiscard}}
          @label="cancel_value"
        />
      </:footer>
    </DModal>
  </template>
}
