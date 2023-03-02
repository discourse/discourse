import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatMessageInReplyToIndicator extends Component {
  @service router;

  get route() {
    if (this.hasThread) {
      return "chat.channel.thread";
    } else {
      return "chat.channel.near-message";
    }
  }

  get model() {
    if (this.hasThread) {
      return [this.args.message.threadId];
    } else {
      return [
        ...this.args.message.channel.routeModels,
        this.args.message.inReplyTo.id,
      ];
    }
  }

  get hasThread() {
    return (
      this.args.message?.channel?.get("threading_enabled") &&
      this.args.message?.threadId
    );
  }
}
