import ChatChannelPane from "./chat-channel-pane";

export default class ChatChannelThreadPane extends ChatChannelPane {
  get selectedMessageIds() {
    return this.chat.activeChannel.activeThread.selectedMessages.mapBy("id");
  }
}
