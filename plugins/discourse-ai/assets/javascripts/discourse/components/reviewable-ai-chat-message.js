import Component from "@glimmer/component";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ReviewableAiChatMessage extends Component {
  get chatChannel() {
    if (!this.args.reviewable.chat_channel) {
      return;
    }
    return ChatChannel.create(this.args.reviewable.chat_channel);
  }
}
