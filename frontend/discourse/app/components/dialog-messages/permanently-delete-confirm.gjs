import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export function buildPermanentlyDeleteConfirmDialogArgs(
  message,
  confirmPhrase,
  didConfirm,
  overrideOpts = {}
) {
  return {
    title: overrideOpts.title || i18n("permanently_delete.title"),
    class: overrideOpts.class || "permanently-delete-confirm",
    bodyComponent: PermanentlyDeleteConfirm,
    bodyComponentModel: {
      message,
      confirmPhrase,
    },
    confirmButtonLabel:
      overrideOpts.confirmButtonLabel || "permanently_delete.controls.delete",
    confirmButtonClass: "btn-danger",
    confirmButtonDisabled: true,
    didConfirm,
  };
}

export default class PermanentlyDeleteConfirm extends Component {
  @service dialog;

  @tracked inputtedConfirmPhrase;

  confirmPhrase = this.args.model.confirmPhrase.trim().toLocaleLowerCase();
  originalDialogClass = this.dialog.class;

  @action
  onInput(event) {
    this.inputtedConfirmPhrase = event.target.value.trim().toLocaleLowerCase();

    this.dialog.set(
      "confirmButtonDisabled",
      this.inputtedConfirmPhrase !== this.confirmPhrase
    );

    if (this.showEasterEgg) {
      this.dialog.set("class", this.dialog.class + " --fire-easter-egg-dialog");
    } else {
      this.dialog.set("class", this.originalDialogClass);
    }
  }

  get showEasterEgg() {
    return (
      this.inputtedConfirmPhrase === this.confirmPhrase + " below to confirm"
    );
  }

  <template>
    <div class="permanently-delete-confirm__message">{{trustHTML
        @model.message
      }}</div>
    <div class="permanently-delete-confirm__instruction">
      <span>{{trustHTML
          (i18n
            "permanently_delete.confirm_instruction" phrase=@model.confirmPhrase
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
  </template>
}
