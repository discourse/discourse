import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { prepPasskeyCredential } from "discourse/lib/webauthn";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class PasskeyLoginButton extends Component {
  @service dialog;
  tagName = "";

  @action
  passkeyLogin() {
    ajax("/session/passkey/challenge.json")
      .then((response) => {
        prepPasskeyCredential(response.challenge, (errorMessage) => {
          this.dialog.alert(errorMessage);
        }).then((credential) => {
          ajax("/session/passkey/auth.json", {
            type: "POST",
            data: {
              publicKeyCredential: credential,
              timezone: moment.tz.guess(),
            },
          })
            .then((result) => {
              if (result && !result.error) {
                // TODO(pmusaraj): See if this is necessary
                window.location.reload();
              } else {
                this.dialog.alert(result.error);
              }
            })
            .catch(popupAjaxError);
        });
      })
      .catch(popupAjaxError);
  }
}
