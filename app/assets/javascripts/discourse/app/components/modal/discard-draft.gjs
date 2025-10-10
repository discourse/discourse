import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
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
      @closeModal={{this.cancelDiscard}}
      class="discard-draft-modal --stacked"
      @hideHeader={{true}}
    >
      <:body>
        <div class="instructions" role="heading" aria-level="1">
          {{i18n "post.cancel_composer.confirm"}}
        </div>
      </:body>

      <:footer>
        <DButton
          @icon="trash-can"
          @label="post.cancel_composer.discard"
          @action={{this.discardDraft}}
          class="btn-danger discard-draft-modal__discard-btn"
        />
        <DButton
          @label="cancel_value"
          @action={{this.cancelDiscard}}
          class="btn-transparent discard-draft-modal__cancel-btn"
        />
      </:footer>
    </DModal>
  </template>
}
