import computed from "ember-addons/ember-computed-decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Ember.Component.extend({
  @computed("secondFactorMethod")
  type(secondFactorMethod) {
    if (secondFactorMethod === SECOND_FACTOR_METHODS.totp) return "tel";
    if (secondFactorMethod === SECOND_FACTOR_METHODS.backup_code) return "text";
  },

  @computed("secondFactorMethod")
  pattern(secondFactorMethod) {
    if (secondFactorMethod === SECOND_FACTOR_METHODS.totp) return "[0-9]{6}";
    if (secondFactorMethod === SECOND_FACTOR_METHODS.backup_code)
      return "[a-z0-9]{16}";
  },

  @computed("secondFactorMethod")
  maxlength(secondFactorMethod) {
    if (secondFactorMethod === SECOND_FACTOR_METHODS.totp) return "6";
    if (secondFactorMethod === SECOND_FACTOR_METHODS.backup_code) return "16";
  }
});
