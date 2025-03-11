import Component from "@ember/component";
import { classNameBindings } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { isWebauthnSupported } from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";

@classNameBindings("hidden", "multiple")
export default class LoginButtons extends Component {
  elementId = "login-buttons";

  @discourseComputed(
    "buttons.length",
    "showLoginWithEmailLink",
    "showPasskeysButton"
  )
  hidden(buttonsCount, showLoginWithEmailLink, showPasskeysButton) {
    return buttonsCount === 0 && !showLoginWithEmailLink && !showPasskeysButton;
  }

  @discourseComputed("buttons.length")
  multiple(buttonsCount) {
    return buttonsCount > 1;
  }

  @discourseComputed
  buttons() {
    return findAll();
  }

  @discourseComputed
  showPasskeysButton() {
    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.enable_passkeys &&
      this.context === "login" &&
      isWebauthnSupported()
    );
  }
}
