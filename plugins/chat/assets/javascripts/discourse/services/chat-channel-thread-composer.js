import ChatChannelComposer from "./chat-channel-composer";

export default class extends ChatChannelComposer {
  get #model() {
    return this.chat.activeChannel.activeThread;
  }
}
