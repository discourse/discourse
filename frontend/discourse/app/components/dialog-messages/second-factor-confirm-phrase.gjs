import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { trustHTML } from "@ember/template";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";
import DialogService from "discourse/dialog-holder/services/dialog";
import CurrentUserService from "discourse/services/current-user";

export default class SecondFactorConfirmPhrase extends Component {
  @service(() => DialogService) dialog;
  @service(() => CurrentUserService) currentUser;

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

    <DTextField
      @autocapitalize="off"
      @autocorrect="off"
      @id="confirm-phrase"
      {{on "input" this.onConfirmPhraseInput}}
    />
  </template>
}
