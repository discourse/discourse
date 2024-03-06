import Component from "@glimmer/component";
import { service } from "@ember/service";
import { and, not } from "truth-helpers";
import DButton from "discourse/components/d-button";

export default class AuthButtons extends Component {
  @service header;

  <template>
    <span class="auth-buttons">
      {{#if (and @canSignUp (not this.header.topic))}}
        <DButton
          class="btn-primary btn-small sign-up-button"
          @action={{@showCreateAccount}}
          @label="sign_up"
        />
      {{/if}}

      <DButton
        class="btn-primary btn-small login-button"
        @action={{@showLogin}}
        @label="log_in"
        @icon="user"
      />
    </span>
  </template>
}
