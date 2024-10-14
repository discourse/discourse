import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default class SecondFactorInput extends Component {
  _focusInput(input) {
    input.focus();
  }

  get isTotp() {
    return this.args.secondFactorMethod === SECOND_FACTOR_METHODS.TOTP;
  }

  get isBackupCode() {
    return this.args.secondFactorMethod === SECOND_FACTOR_METHODS.BACKUP_CODE;
  }

  get type() {
    if (this.isTotp) {
      return "tel";
    } else if (this.isBackupCode) {
      return "text";
    }
  }

  get pattern() {
    if (this.isTotp) {
      return "[0-9]{6}";
    } else if (this.isBackupCode) {
      return "[a-z0-9]{16}";
    }
  }

  get maxlength() {
    if (this.isTotp) {
      return "6";
    } else if (this.isBackupCode) {
      return "32";
    }
  }

  <template>
    <input
      type={{this.type}}
      pattern={{this.pattern}}
      maxlength={{this.maxlength}}
      autocomplete="one-time-code"
      autocapitalize="off"
      autocorrect="off"
      autofocus="autofocus"
      class="second-factor-token-input"
      ...attributes
      {{didInsert this._focusInput}}
    />
  </template>
}
