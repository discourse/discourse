import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import TextField from "discourse/components/text-field";
import { i18n } from "discourse-i18n";

export default class SecondFactorConfirmPhrase extends Component {
  @service dialog;
  @service currentUser;

  disabledString = i18n("user.second_factor.disable");

  @action
  onConfirmPhraseInput(event) {
    this.dialog.set(
      "confirmButtonDisabled",
      event.target.value.toLocaleLowerCase() !==
        this.disabledString.toLocaleLowerCase()
    );
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
      {{trustHTML
        (i18n
          "user.second_factor.delete_confirm_instruction"
          confirm=this.disabledString
        )
      }}
    </p>

    <TextField
      {{on "input" this.onConfirmPhraseInput}}
      @id="confirm-phrase"
      @autocorrect="off"
      @autocapitalize="off"
    />
  </template>
}
