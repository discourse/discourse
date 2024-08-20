import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class AuthButtons extends Component {
  @service header;

  get showSignupButton() {
    return (
      this.args.canSignUp &&
      !this.header.headerButtonsHidden.includes("signup") &&
      !this.args.topicInfoVisible
    );
  }

  get showLoginButton() {
    return !this.header.headerButtonsHidden.includes("login");
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
          @label="log_in"
          @icon="user"
        />
      {{/if}}
    </span>
  </template>
}
