import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ActivationEmailForm extends Component {
  @action
  newEmailChanged() {
    this.args.updateNewEmail?.();
  }
}
