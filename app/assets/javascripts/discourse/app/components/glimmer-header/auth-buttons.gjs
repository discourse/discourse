import and from "truth-helpers/helpers/and";
import DButton from "discourse/components/d-button";
import not from "truth-helpers/helpers/not";

const AuthButtons = <template>
  <span class="header-buttons">
    {{#if (and @canSignUp (not @topic))}}
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
</template>;

export default AuthButtons;
