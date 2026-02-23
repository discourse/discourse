import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelPins extends DiscourseRoute {
  @service chatStateManager;
  @service chat;
  @service chatApi;

  async model() {
    const channel = this.modelFor("chat.channel");
    const pinnedMessages = await this.chatApi.pinnedMessages(channel);
    return { channel, pinnedMessages };
  }

  @action
  activate() {
    this.chat.activeMessage = null;
    this.chatStateManager.openSidePanel();
  }

  @action
  deactivate() {
    this.chatStateManager.closeSidePanel();
  }
}
