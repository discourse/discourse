import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class DismissNew extends Component {
  @action
  dismissed() {
    this.args.model.dismissCallback();
    this.args.closeModal();
  }
}
