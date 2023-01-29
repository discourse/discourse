import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatDraftChannelController extends Controller {
  @service chat;

  @action
  onSwitchChannel(channel) {
    return this.chat.openChannel(channel);
  }
}
