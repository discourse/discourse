import Modal from "discourse/controllers/modal";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatChannelToggleController extends Modal {
  @service chat;
  @service router;

  chatChannel = null;

  @action
  channelStatusChanged(channel) {
    this.send("closeModal");
    this.router.transitionTo("chat.channel", ...channel.routeModels);
  }
}
