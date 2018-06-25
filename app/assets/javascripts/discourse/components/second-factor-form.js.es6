import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed("secondFactorMethod")
  secondFactorTitle(secondFactorMethod) {
    return secondFactorMethod === 1
      ? I18n.t("login.second_factor_title")
      : I18n.t("login.second_factor_backup_title");
  },

  @computed("secondFactorMethod")
  secondFactorDescription(secondFactorMethod) {
    return secondFactorMethod === 1
      ? I18n.t("login.second_factor_description")
      : I18n.t("login.second_factor_backup_description");
  },

  @computed("secondFactorMethod")
  linkText(secondFactorMethod) {
    return secondFactorMethod === 1
      ? "login.second_factor_backup"
      : "login.second_factor";
  },

  actions: {
    toggleSecondFactorMethod() {
      const secondFactorMethod = this.get("secondFactorMethod");
      this.set("loginSecondFactor", "");
      if (secondFactorMethod === 1) {
        this.set("secondFactorMethod", 2);
      } else {
        this.set("secondFactorMethod", 1);
      }
    }
  }
});
