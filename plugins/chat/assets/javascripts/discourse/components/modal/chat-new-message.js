import Component from "@ember/component";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatNewMessageModal extends Component {
  @service chat;
}
