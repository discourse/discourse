import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import I18n from "discourse-i18n";

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
