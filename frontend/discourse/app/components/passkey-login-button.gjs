import DButton from "discourse/ui-kit/d-button";

const PasskeyLoginButton = <template>
  <DButton
    class="btn-social passkey-login-button"
    @action={{@passkeyLogin}}
    @icon="user"
    @label="login.passkey.name"
  />
</template>;

export default PasskeyLoginButton;
