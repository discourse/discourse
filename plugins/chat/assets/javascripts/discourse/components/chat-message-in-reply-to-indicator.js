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
      return [
        ...this.args.message.channel.routeModels,
        this.args.message.thread.id,
      ];
    } else {
      return [
        ...this.args.message.channel.routeModels,
        this.args.message.inReplyTo.id,
      ];
    }
  }

  get hasThread() {
    return (
      this.args.message?.channel?.threadingEnabled &&
      this.args.message?.thread?.id
    );
  }
}
