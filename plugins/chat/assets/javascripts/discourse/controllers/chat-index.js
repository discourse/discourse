import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatIndexController extends Controller {
  @service chat;

  @action
  selectChannel(channel) {
    return this.chat.openChannel(channel);
  }
}
