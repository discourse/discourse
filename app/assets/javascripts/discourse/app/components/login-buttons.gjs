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

{{#each this.buttons as |b|}}
  <button
    type="button"
    class="btn btn-social {{b.name}}"
    {{on "click" (action this.externalLogin b)}}
    aria-label={{b.screenReaderTitle}}
  >
    {{#if b.isGoogle}}
      <GoogleIcon />
    {{else if b.icon}}
      {{d-icon b.icon}}
    {{else}}
      {{d-icon "right-to-bracket"}}
    {{/if}}
    <span class="btn-social-title">{{b.title}}</span>
  </button>
{{/each}}

{{#if this.showPasskeysButton}}
  <PasskeyLoginButton @passkeyLogin={{this.passkeyLogin}} />
{{/if}}

<PluginOutlet @name="after-login-buttons" />