import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class PermanentlyDeleteConfirm extends Component {
  @service dialog;

  confirmPhrase = i18n("post.controls.permanently_delete_confirm_phrase");

  @action
  onInput(event) {
    this.dialog.set(
      "confirmButtonDisabled",
      event.target.value.trim().toLocaleLowerCase() !==
        this.confirmPhrase.trim().toLocaleLowerCase()
    );
  }

  <template>
    <p>{{trustHTML @model.message}}</p>
    <div class="permanently-delete-confirm__instruction">
      <span>{{trustHTML
          (i18n
            "post.controls.permanently_delete_confirm_instruction"
            phrase=this.confirmPhrase
          )
        }}</span>
      <input
        {{on "input" this.onInput}}
        type="text"
        class="confirmation-phrase"
        placeholder={{this.confirmPhrase}}
      />
    </div>
  </template>
}
