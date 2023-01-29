import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class DialogHolder extends Component {
  @service dialog;

  @action
  async handleButtonAction(btn) {
    if (btn.action && typeof btn.action === "function") {
      await btn.action();
    }

    this.dialog.cancel();
  }
}
