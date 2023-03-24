import ChatLivePanel from "./chat-live-panel";

export default class ChatThreadLivePanel extends ChatLivePanel {
  get #model() {
    return this.chat.activeChannel.activeThread;
  }

  get showMessageSeparators() {
    return false;
  }

  get messageActionsAnchorClasses() {
    return {
      mobileAnchor: ".chat-message-actions-mobile-anchor--thread",
      desktopAnchor: ".chat-message-actions-desktop-anchor--thread",
    };
  }
}
