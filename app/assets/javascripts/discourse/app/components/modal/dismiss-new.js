import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class DismissNew extends Component {
  @service modal;

  @action
  closeModal() {
    this.args.model.dismissCallback();
    this.modal.close();
  }
}
