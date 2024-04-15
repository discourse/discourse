import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";

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
