import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import discourseDebounce from "discourse/lib/debounce";
import getURL from "discourse/lib/get-url";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class PermanentlyDeleteConfirm extends Component {
  @tracked inputtedConfirmPhrase = "";

  #easterEggAudio;

  get confirmPhrase() {
    return this.args.model.confirmPhrase.trim().toLocaleLowerCase();
  }

  get phraseMatches() {
    return this.inputtedConfirmPhrase === this.confirmPhrase;
  }

  get showEasterEgg() {
    return (
      this.inputtedConfirmPhrase === this.confirmPhrase + " below to confirm"
    );
  }

  @action
  onInput(event) {
    this.inputtedConfirmPhrase = event.target.value.trim().toLocaleLowerCase();
    discourseDebounce(this, this.maybePlayEasterEggSound, 300);
  }

  maybePlayEasterEggSound() {
    if (!this.showEasterEgg) {
      return;
    }
    this.#easterEggAudio ??= new Audio(getURL("/audio/firelaugh.mp3"));
    this.#easterEggAudio.currentTime = 0;
    this.#easterEggAudio.play();
  }

  @action
  confirm() {
    this.args.model.didConfirm?.();
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "permanently_delete.title"}}
      @closeModal={{@closeModal}}
      class={{dConcatClass
        "permanently-delete-confirm-modal"
        (if this.showEasterEgg "--fire-easter-egg-modal")
      }}
    >
      <:body>
        <div class="permanently-delete-confirm-modal__message">{{trustHTML
            @model.message
          }}</div>
        <div class="permanently-delete-confirm-modal__instruction">
          <span>{{trustHTML
              (i18n
                "permanently_delete.confirm_instruction"
                phrase=@model.confirmPhrase
              )
            }}</span>
          <input
            {{on "input" this.onInput}}
            name="confirmationPhrase"
            type="text"
            class="confirmation-phrase"
            placeholder={{@model.confirmPhrase}}
          />

          {{#if this.showEasterEgg}}
            Comedian, eh?
            <div class="fire-easter-egg"></div>
          {{/if}}
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.confirm}}
          @disabled={{not this.phraseMatches}}
          @label="permanently_delete.controls.delete"
          class="btn-danger"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
