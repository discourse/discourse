import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

export default class AuthButtons extends Component {
  @service header;
  @service mobileTabBar;

  get showSignupButton() {
    return (
      this.args.canSignUp &&
      !this.header.headerButtonsHidden.includes("signup") &&
      !this.args.topicInfoVisible
    );
  }

  // The tab bar holds logging in where creating would be
  get showLoginButton() {
    return (
      !this.mobileTabBar.enabled &&
      !this.header.headerButtonsHidden.includes("login")
    );
  }

  <template>
    <span class="auth-buttons">
      {{#if this.showSignupButton}}
        <DButton
          class="btn-primary btn-small sign-up-button"
          @action={{@showCreateAccount}}
          @label="sign_up"
        />
      {{/if}}

      {{#if this.showLoginButton}}
        <DButton
          class="btn-primary btn-small login-button"
          @action={{@showLogin}}
          @icon="user"
          @label="log_in"
        />
      {{/if}}
    </span>
  </template>
}
