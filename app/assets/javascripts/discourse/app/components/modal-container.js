import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ModalContainer extends Component {
  @service modal;

  @action
  closeModal(data) {
    this.modal.close(data);
  }
}
