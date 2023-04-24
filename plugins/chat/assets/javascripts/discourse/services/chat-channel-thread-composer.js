import ChatChannelComposer from "./chat-channel-composer";

export default class extends ChatChannelComposer {
  get model() {
    return this.chat.activeChannel.activeThread;
  }

  _persistDraft() {
    // eslint-disable-next-line no-console
    console.debug(
      "Drafts are unsupported for chat threads at this point in time"
    );
    return;
  }
}
