/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import GoogleIcon from "discourse/components/google-icon";
import PasskeyLoginButton from "discourse/components/passkey-login-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { isWebauthnSupported } from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";
import { i18n } from "discourse-i18n";

@tagName("")
export default class LoginButtons extends Component {
  @computed("buttons.length", "showLoginWithEmailLink", "showPasskeysButton")
  get hidden() {
    return (
      this.buttons?.length === 0 &&
      !this.showLoginWithEmailLink &&
      !this.showPasskeysButton
    );
  }

  @computed("buttons.length")
  get multiple() {
    return this.buttons?.length > 1;
  }

  @computed
  get buttons() {
    return findAll();
  }

  @computed
  get showPasskeysButton() {
    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.enable_passkeys &&
      this.context === "login" &&
      isWebauthnSupported()
    );
  }

  <template>
    <div
      id="login-buttons"
      class={{concatClass
        (if this.hidden "hidden")
        (if this.multiple "multiple")
      }}
      ...attributes
    >
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
    </div>
  </template>
}
