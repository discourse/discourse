import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecurityKeyForm extends Component {
  @action
  useAnotherMethod(event) {
    event.preventDefault();
    this.args.setShowSecurityKey?.(false);
    this.args.setShowSecondFactor?.(true);

    if (this.args.totpEnabled) {
      this.args.setSecondFactorMethod?.(SECOND_FACTOR_METHODS.TOTP);
    } else if (this.args.backupEnabled) {
      this.args.setSecondFactorMethod?.(SECOND_FACTOR_METHODS.BACKUP_CODE);
    }
  }

  <template>
    <div id="security-key">
      <DButton
        @action={{@action}}
        @icon="key"
        @label="login.security_key_authenticate"
        id="security-key-authenticate-button"
        class="btn-large btn-primary"
      />
      <p>
        {{#if @otherMethodAllowed}}
          <a
            {{on "click" this.useAnotherMethod}}
            href
            class="toggle-second-factor-method"
          >{{i18n "login.security_key_alternative"}}</a>
        {{/if}}
      </p>
    </div>
  </template>
}
