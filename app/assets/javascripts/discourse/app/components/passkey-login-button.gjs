import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class PasskeyLoginButton extends Component {
  <template>
    <DButton
      @action={{this.args.passkeyLogin}}
      @icon="user"
      @label="login.passkey.name"
      class="btn btn-social passkey-login-button"
    />
  </template>
}
