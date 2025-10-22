/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { classNameBindings } from "@ember-decorators/component";
import GoogleIcon from "discourse/components/google-icon";
import PasskeyLoginButton from "discourse/components/passkey-login-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import discourseComputed from "discourse/lib/decorators";
import { isWebauthnSupported } from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";
import { i18n } from "discourse-i18n";

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

  <template>
    {{#each this.buttons as |b|}}
      {{#if b.isDiscourseID}}
        <div class="discourse-id__wrapper">
          <button
            type="button"
            class="btn btn-social {{b.name}}"
            {{on "click" (fn this.externalLogin b)}}
            aria-label={{b.screenReaderTitle}}
          >
            {{icon b.icon}}
            <span class="btn-social-title">{{b.title}}</span>
          </button>
          <div class="btn-discourse-id__suffix">
            <span class="btn-discourse-id__description">
              {{i18n "login.works_with"}}</span>
            {{icon "fab-google"}}
            {{icon "fab-apple"}}
            {{icon "fab-facebook"}}
            {{icon "fab-github"}}
          </div>
        </div>
      {{else}}
        <button
          type="button"
          class="btn btn-social {{b.name}}"
          {{on "click" (fn this.externalLogin b)}}
          aria-label={{b.screenReaderTitle}}
        >
          {{#if b.isGoogle}}
            <GoogleIcon />
          {{else if b.icon}}
            {{icon b.icon}}
          {{else}}
            {{icon "right-to-bracket"}}
          {{/if}}
          <span class="btn-social-title">{{b.title}}</span>
        </button>
      {{/if}}
    {{/each}}

    {{#if this.showPasskeysButton}}
      <PasskeyLoginButton @passkeyLogin={{this.passkeyLogin}} />
    {{/if}}

    <PluginOutlet @name="after-login-buttons" />
  </template>
}
