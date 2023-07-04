import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import FLASH_TYPE_MAPPINGS from "discourse/components/d-modal";

export default class ModalContainer extends Component {
  @service modal;

  get flashTypes() {
    return FLASH_TYPE_MAPPINGS;
  }

  @action
  closeModal(data) {
    this.modal.close(data);
  }
}
