import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import TextField from "discourse/components/text-field";
import { i18n } from "discourse-i18n";

export default class SecondFactorConfirmPhrase extends Component {
  @service dialog;
  @service currentUser;

  @tracked confirmPhraseInput = "";
  disabledString = i18n("user.second_factor.disable");

  @action
  onConfirmPhraseInput() {
    if (this.confirmPhraseInput === this.disabledString) {
      this.dialog.set("confirmButtonDisabled", false);
    } else {
      this.dialog.set("confirmButtonDisabled", true);
    }
  }

  <template>
    {{i18n "user.second_factor.delete_confirm_header"}}

    <ul>
      {{#each @model.totps as |totp|}}
        <li>{{totp.name}}</li>
      {{/each}}

      {{#each @model.security_keys as |sk|}}
        <li>{{sk.name}}</li>
      {{/each}}

      {{#if this.currentUser.second_factor_backup_enabled}}
        <li>{{i18n "user.second_factor_backup.title"}}</li>
      {{/if}}
    </ul>

    <p>
      {{htmlSafe
        (i18n
          "user.second_factor.delete_confirm_instruction"
          confirm=this.disabledString
        )
      }}
    </p>

    <TextField
      @value={{this.confirmPhraseInput}}
      {{on "input" this.onConfirmPhraseInput}}
      @id="confirm-phrase"
      @autocorrect="off"
      @autocapitalize="off"
    />
  </template>
}
