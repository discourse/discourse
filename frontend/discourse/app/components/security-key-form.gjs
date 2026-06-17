import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class SecurityKeyForm extends Component {
  get showSecurityKeyButton() {
    // when the granular args aren't passed, keep the legacy single-button
    // rendering driven by `@action`
    return this.args.securityKeysEnabled ?? true;
  }

  get securityKeyAction() {
    return this.args.securityKeyAction ?? this.args.action;
  }

  get securityKeyLabel() {
    return this.args.passkeysEnabled
      ? "login.use_security_key"
      : "login.security_key_authenticate";
  }

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
      {{#if @passkeysEnabled}}
        <DButton
          @action={{@passkeyAction}}
          @icon="user"
          @label="login.use_passkey"
          id="passkey-authenticate-button"
          class="btn-large btn-primary"
        />
      {{/if}}
      {{#if this.showSecurityKeyButton}}
        <DButton
          @action={{this.securityKeyAction}}
          @icon="key"
          @label={{this.securityKeyLabel}}
          id="security-key-authenticate-button"
          class="btn-large {{if @passkeysEnabled 'btn-default' 'btn-primary'}}"
        />
      {{/if}}
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
