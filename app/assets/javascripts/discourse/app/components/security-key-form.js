import Component from "@ember/component";
import { action } from "@ember/object";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Component.extend({
  @action
  useAnotherMethod(event) {
    event?.preventDefault();
    this.set("showSecurityKey", false);
    this.set("showSecondFactor", true);

    if (this.totpEnabled) {
      this.set("secondFactorMethod", SECOND_FACTOR_METHODS.TOTP);
    } else if (this.backupEnabled) {
      this.set("secondFactorMethod", SECOND_FACTOR_METHODS.BACKUP_CODE);
    }
  },
});
