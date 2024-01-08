import Controller from "@ember/controller";
import { inject as service } from "@ember/service";

export default class ChatIndexController extends Controller {
  @service chat;
  @service siteSettings;

  get directMessagesEnabled() {
    return this.siteSettings.chat_max_direct_message_users > 0;
  }
}
