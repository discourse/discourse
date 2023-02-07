import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatChannelController extends Controller {
  @service chat;

  targetMessageId = null;

  // Backwards-compatibility
  queryParams = ["messageId"];

  @action
  switchChannel(channel) {
    this.chat.openChannel(channel);
  }
}
