import Service, { inject as service } from "@ember/service";

export default class ChatChannelThreadIndexPane extends Service {
  @service chat;
  @service chatStateManager;

  close() {
    this.chatStateManager.closeSidePanel();
  }

  open() {
    this.chatStateManager.openSidePanel();
  }
}
