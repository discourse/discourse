import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecondFactorForm extends Component {
  @discourseComputed("secondFactorMethod")
  secondFactorTitle(secondFactorMethod) {
    switch (secondFactorMethod) {
      case SECOND_FACTOR_METHODS.TOTP:
        return i18n("login.second_factor_title");
      case SECOND_FACTOR_METHODS.SECURITY_KEY:
        return i18n("login.second_factor_title");
      case SECOND_FACTOR_METHODS.BACKUP_CODE:
        return i18n("login.second_factor_backup_title");
    }
  }

  @discourseComputed("secondFactorMethod")
  secondFactorDescription(secondFactorMethod) {
    switch (secondFactorMethod) {
      case SECOND_FACTOR_METHODS.TOTP:
        return i18n("login.second_factor_description");
      case SECOND_FACTOR_METHODS.SECURITY_KEY:
        return i18n("login.security_key_description");
      case SECOND_FACTOR_METHODS.BACKUP_CODE:
        return i18n("login.second_factor_backup_description");
    }
  }

  @discourseComputed("secondFactorMethod", "isLogin")
  linkText(secondFactorMethod, isLogin) {
    if (isLogin) {
      return secondFactorMethod === SECOND_FACTOR_METHODS.TOTP
        ? "login.second_factor_backup"
        : "login.second_factor";
    } else {
      return secondFactorMethod === SECOND_FACTOR_METHODS.TOTP
        ? "user.second_factor_backup.use"
        : "user.second_factor.use";
    }
  }

  @discourseComputed("backupEnabled", "totpEnabled", "secondFactorMethod")
  showToggleMethodLink(backupEnabled, totpEnabled, secondFactorMethod) {
    return (
      backupEnabled &&
      totpEnabled &&
      secondFactorMethod !== SECOND_FACTOR_METHODS.SECURITY_KEY
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
}
