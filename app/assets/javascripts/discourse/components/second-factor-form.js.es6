import computed from "ember-addons/ember-computed-decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Ember.Component.extend({
  @computed("secondFactorMethod")
  secondFactorTitle(secondFactorMethod) {
    return secondFactorMethod === SECOND_FACTOR_METHODS.TOTP
      ? I18n.t("login.second_factor_title")
      : I18n.t("login.second_factor_backup_title");
  },

  @computed("secondFactorMethod")
  secondFactorDescription(secondFactorMethod) {
    return secondFactorMethod === SECOND_FACTOR_METHODS.TOTP
      ? I18n.t("login.second_factor_description")
      : I18n.t("login.second_factor_backup_description");
  },

  @computed("secondFactorMethod", "isLogin")
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
  },

  actions: {
    toggleSecondFactorMethod() {
      const secondFactorMethod = this.secondFactorMethod;
      this.set("secondFactorToken", "");
      if (secondFactorMethod === SECOND_FACTOR_METHODS.TOTP) {
        this.set("secondFactorMethod", SECOND_FACTOR_METHODS.BACKUP_CODE);
      } else {
        this.set("secondFactorMethod", SECOND_FACTOR_METHODS.TOTP);
      }
    }
  }
});
