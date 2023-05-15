import Service, { inject as service } from "@ember/service";

export default class ChatChannelThreadListPane extends Service {
  @service chat;
  @service chatStateManager;

  close() {
    this.chatStateManager.closeSidePanel();
  }

  open() {
    this.chat.activeMessage = null;
    this.chatStateManager.openSidePanel();
  }
}
