import ChatChannelPane from "./chat-channel-pane";
import { inject as service } from "@ember/service";

export default class ChatChannelThreadPane extends ChatChannelPane {
  @service chatChannelThreadComposer;

  get selectedMessageIds() {
    return this.chat.activeChannel.activeThread.selectedMessages.mapBy("id");
  }

  get composerService() {
    return this.chatChannelThreadComposer;
  }

  get lastCurrentUserMessage() {
    const lastCurrentUserMessage =
      this.chat.activeChannel.activeThread.messages.findLast(
        (message) => message.user.id === this.currentUser.id
      );

    if (!lastCurrentUserMessage) {
      return;
    }

    if (lastCurrentUserMessage.staged || lastCurrentUserMessage.error) {
      return;
    }

    return lastCurrentUserMessage;
  }
}
