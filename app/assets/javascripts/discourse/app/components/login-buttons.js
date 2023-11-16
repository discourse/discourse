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
    "showPasskeysButton"
  )
  hidden(buttonsCount, showLoginWithEmailLink, showPasskeysButton) {
    return buttonsCount === 0 && !showLoginWithEmailLink && !showPasskeysButton;
  },

  @discourseComputed
  buttons() {
    return findAll();
  },

  @discourseComputed
  showPasskeysButton() {
    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.enable_passkeys &&
      this.context === "login" &&
      isWebauthnSupported()
    );
  },
});
