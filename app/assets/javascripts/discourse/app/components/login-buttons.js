import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { findAll } from "discourse/models/login-method";
import { isWebauthnSupported } from "discourse/lib/webauthn";

export default Component.extend({
  elementId: "login-buttons",
  classNameBindings: ["hidden"],

  @discourseComputed("buttons.length", "showLoginWithEmailLink")
  hidden(buttonsCount, showLoginWithEmailLink) {
    return buttonsCount === 0 && !showLoginWithEmailLink;
  },

  @discourseComputed
  buttons() {
    return findAll();
  },

  @discourseComputed
  canUsePasskeys() {
    return isWebauthnSupported() && this.siteSettings.experimental_passkeys;
  },

  actions: {
    externalLogin(provider) {
      this.externalLogin(provider);
    },
  },
});
