import Component from "@glimmer/component";
import I18n from "I18n";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class SecondFactorConfirmPhrase extends Component {
  @service dialog;
  @service currentUser;

  @tracked confirmPhraseInput = "";
  disabledString = I18n.t("user.second_factor.disable");

  @action
  onConfirmPhraseInput() {
    if (this.confirmPhraseInput === this.disabledString) {
      this.dialog.set("confirmButtonDisabled", false);
    } else {
      this.dialog.set("confirmButtonDisabled", true);
    }
  }
}
