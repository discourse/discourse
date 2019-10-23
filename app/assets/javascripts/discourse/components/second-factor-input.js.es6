import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Component.extend({
  @computed("secondFactorMethod")
  type(secondFactorMethod) {
    if (secondFactorMethod === SECOND_FACTOR_METHODS.TOTP) return "tel";
    if (secondFactorMethod === SECOND_FACTOR_METHODS.BACKUP_CODE) return "text";
  },

  @computed("secondFactorMethod")
  pattern(secondFactorMethod) {
    if (secondFactorMethod === SECOND_FACTOR_METHODS.TOTP) return "[0-9]{6}";
    if (secondFactorMethod === SECOND_FACTOR_METHODS.BACKUP_CODE)
      return "[a-z0-9]{16}";
  },

  @computed("secondFactorMethod")
  maxlength(secondFactorMethod) {
    if (secondFactorMethod === SECOND_FACTOR_METHODS.TOTP) return "6";
    if (secondFactorMethod === SECOND_FACTOR_METHODS.BACKUP_CODE) return "16";
  }
});
