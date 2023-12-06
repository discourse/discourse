import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { EMBER_MAJOR_VERSION } from "discourse/lib/ember-version";

export default class ModalContainer extends Component {
  @service modal;

  @action
  closeModal(data) {
    this.modal.close(data);
  }

  get renderLegacy() {
    return EMBER_MAJOR_VERSION < 4;
  }
}
