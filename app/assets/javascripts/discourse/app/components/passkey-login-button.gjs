import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getPasskeyCredential } from "discourse/lib/webauthn";

export default class PasskeyLoginButton extends Component {
  @service dialog;
  tagName = "";

  @action
  async passkeyLogin() {
    try {
      const response = await ajax("/session/passkey/challenge.json");

      const publicKeyCredential = await getPasskeyCredential(
        response.challenge,
        (errorMessage) => this.dialog.alert(errorMessage)
      );

      const authResult = await ajax("/session/passkey/auth.json", {
        type: "POST",
        data: { publicKeyCredential },
      });

      if (authResult && !authResult.error) {
        window.location.reload();
      } else {
        this.dialog.alert(authResult.error);
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DButton
      @action={{this.passkeyLogin}}
      @icon="user"
      @label="login.passkey.name"
      class="btn btn-social passkey-login-button"
    />
  </template>
}
