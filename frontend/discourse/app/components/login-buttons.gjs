import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import GoogleIcon from "discourse/components/google-icon";
import PasskeyLoginButton from "discourse/components/passkey-login-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import { isWebauthnSupported } from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class LoginButtons extends Component {
  @service siteSettings;

  get hidden() {
    return (
      this.buttons?.length === 0 &&
      !this.args.showLoginWithEmailLink &&
      !this.showPasskeysButton
    );
  }

  get multiple() {
    return this.buttons?.length > 1;
  }

  @cached
  get buttons() {
    return findAll();
  }

  get showPasskeysButton() {
    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.enable_passkeys &&
      this.args.context === "login" &&
      isWebauthnSupported()
    );
  }

  <template>
    <div
      class={{dConcatClass
        (if this.hidden "hidden")
        (if this.multiple "multiple")
      }}
      id="login-buttons"
      ...attributes
    >
      {{#each this.buttons as |b|}}
        {{#if b.isDiscourseID}}
          <div class="discourse-id__wrapper">
            <button
              aria-label={{b.screenReaderTitle}}
              class="btn btn-social {{b.name}}"
              type="button"
              {{on "click" (fn @externalLogin b)}}
            >
              {{dIcon b.icon}}
              <span class="btn-social-title">{{b.title}}</span>
            </button>
            <div class="btn-discourse-id__suffix">
              <span class="btn-discourse-id__description">
                {{i18n "login.works_with"}}</span>
              {{dIcon "fab-google"}}
              {{dIcon "fab-apple"}}
              {{dIcon "fab-facebook"}}
              {{dIcon "fab-github"}}
            </div>
          </div>
        {{else}}
          <button
            aria-label={{b.screenReaderTitle}}
            class="btn btn-social {{b.name}}"
            type="button"
            {{on "click" (fn @externalLogin b)}}
          >
            {{#if b.isGoogle}}
              <GoogleIcon />
            {{else if b.icon}}
              {{dIcon b.icon}}
            {{else}}
              {{dIcon "right-to-bracket"}}
            {{/if}}
            <span class="btn-social-title">{{b.title}}</span>
          </button>
        {{/if}}
      {{/each}}

      {{#if this.showPasskeysButton}}
        <PasskeyLoginButton @passkeyLogin={{@passkeyLogin}} />
      {{/if}}

      <PluginOutlet @name="after-login-buttons" />
    </div>
  </template>
}
