import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ActivationEmailForm extends Component {
  @action
  newEmailChanged(value) {
    this.args.updateNewEmail?.(value);
  }
}
