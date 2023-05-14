import Controller from "@ember/controller";
import { inject as service } from "@ember/service";

export default class ChatIndexController extends Controller {
  @service chat;

  get showMobileDirectMessageButton() {
    return this.site.mobileView && this.canCreateDirectMessageChannel;
  }

  get canCreateDirectMessageChannel() {
    return this.chat.userCanDirectMessage;
  }
}
