import Modal from "discourse/controllers/modal";
import { action } from "@ember/object";

export default class ChatChannelSelectorModalController extends Modal {
  @action
  closeSelf() {
    this.send("closeModal");
  }
}
