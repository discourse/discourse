/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecondFactorForm extends Component {
  @computed("secondFactorMethod")
  get secondFactorTitle() {
    switch (this.secondFactorMethod) {
      case SECOND_FACTOR_METHODS.TOTP:
        return i18n("login.second_factor_title");
      case SECOND_FACTOR_METHODS.SECURITY_KEY:
        return i18n("login.second_factor_title");
      case SECOND_FACTOR_METHODS.BACKUP_CODE:
        return i18n("login.second_factor_backup_title");
    }
  }

  @computed("secondFactorMethod")
  get secondFactorDescription() {
    switch (this.secondFactorMethod) {
      case SECOND_FACTOR_METHODS.TOTP:
        return i18n("login.second_factor_description");
      case SECOND_FACTOR_METHODS.SECURITY_KEY:
        return i18n("login.security_key_description");
      case SECOND_FACTOR_METHODS.BACKUP_CODE:
        return i18n("login.second_factor_backup_description");
    }
  }

  @computed("secondFactorMethod", "isLogin")
  get linkText() {
    if (this.isLogin) {
      return this.secondFactorMethod === SECOND_FACTOR_METHODS.TOTP
        ? "login.second_factor_backup"
        : "login.second_factor";
    } else {
      return this.secondFactorMethod === SECOND_FACTOR_METHODS.TOTP
        ? "user.second_factor_backup.use"
        : "user.second_factor.use";
    }
  }

  @computed("backupEnabled", "totpEnabled", "secondFactorMethod")
  get showToggleMethodLink() {
    return (
      this.backupEnabled &&
      this.totpEnabled &&
      this.secondFactorMethod !== SECOND_FACTOR_METHODS.SECURITY_KEY
    );
  }

  @action
  toggleSecondFactorMethod(event) {
    event?.preventDefault();
    const secondFactorMethod = this.secondFactorMethod;
    this.set("secondFactorToken", "");
    if (secondFactorMethod === SECOND_FACTOR_METHODS.TOTP) {
      this.set("secondFactorMethod", SECOND_FACTOR_METHODS.BACKUP_CODE);
    } else {
      this.set("secondFactorMethod", SECOND_FACTOR_METHODS.TOTP);
    }
  }

  <template>
    <div id="second-factor">
      <h3>{{this.secondFactorTitle}}</h3>

      {{#if this.optionalText}}
        <p>{{htmlSafe this.optionalText}}</p>
      {{/if}}

      <p class="second-factor__description">{{this.secondFactorDescription}}</p>

      {{yield}}

      {{#if this.showToggleMethodLink}}
        <p>
          <a
            href
            class="toggle-second-factor-method"
            {{on "click" this.toggleSecondFactorMethod}}
          >{{i18n this.linkText}}</a>
        </p>
      {{/if}}
    </div>
  </template>
}
