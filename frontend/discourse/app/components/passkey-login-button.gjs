import DButton from "discourse/components/d-button";

const PasskeyLoginButton = <template>
  <DButton
    @action={{@passkeyLogin}}
    @icon="user"
    @label="login.passkey.name"
    class="btn-social passkey-login-button"
  />
</template>;

export default PasskeyLoginButton;
