import computed from "ember-addons/ember-computed-decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Ember.Component.extend({
  @computed("secondFactorMethod")
  secondFactorTitle(secondFactorMethod) {
    return secondFactorMethod === SECOND_FACTOR_METHODS.totp
      ? I18n.t("login.second_factor_title")
      : I18n.t("login.second_factor_backup_title");
  },

  @computed("secondFactorMethod")
  secondFactorDescription(secondFactorMethod) {
    return secondFactorMethod === SECOND_FACTOR_METHODS.totp
      ? I18n.t("login.second_factor_description")
      : I18n.t("login.second_factor_backup_description");
  },

  @computed("secondFactorMethod")
  linkText(secondFactorMethod) {
    return secondFactorMethod === SECOND_FACTOR_METHODS.totp
      ? "login.second_factor_backup"
      : "login.second_factor";
  },

  actions: {
    toggleSecondFactorMethod() {
      const secondFactorMethod = this.get("secondFactorMethod");
      this.set("loginSecondFactor", "");
      if (secondFactorMethod === SECOND_FACTOR_METHODS.totp) {
        this.set("secondFactorMethod", SECOND_FACTOR_METHODS.backup_code);
      } else {
        this.set("secondFactorMethod", SECOND_FACTOR_METHODS.totp);
      }
    }
  }
});
