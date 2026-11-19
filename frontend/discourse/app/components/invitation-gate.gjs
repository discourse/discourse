import LoginButtons from "discourse/components/login-buttons";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="invitation-gate">
    <h1>{{i18n "login.invitation_gate.title"}}</h1>
    <p>{{i18n "login.invitation_gate.description"}}</p>
    <p>{{i18n "login.invitation_gate.existing_member"}}</p>
    <LoginButtons
      class="invitation-gate__buttons"
      @context="login"
      @externalLogin={{@externalLogin}}
    />
  </section>
</template>
