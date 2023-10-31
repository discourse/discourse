import Component from "@ember/component";
import { isWebauthnSupported } from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  elementId: "login-buttons",
  classNameBindings: ["hidden"],

  @discourseComputed(
    "buttons.length",
    "showLoginWithEmailLink",
    "canUsePasskeys"
  )
  hidden(buttonsCount, showLoginWithEmailLink, canUsePasskeys) {
    return buttonsCount === 0 && !showLoginWithEmailLink && !canUsePasskeys;
  },

  @discourseComputed
  buttons() {
    return findAll();
  },

  @discourseComputed
  canUsePasskeys() {
    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.experimental_passkeys &&
      isWebauthnSupported()
    );
  },
});
