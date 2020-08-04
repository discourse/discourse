import Component from "@ember/component";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Component.extend({
  actions: {
    useAnotherMethod() {
      this.set("showSecurityKey", false);
      this.set("showSecondFactor", true);
      this.set("secondFactorMethod", SECOND_FACTOR_METHODS.TOTP);
    }
  }
});
