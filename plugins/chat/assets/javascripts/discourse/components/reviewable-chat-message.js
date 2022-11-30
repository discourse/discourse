import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { cached } from "@glimmer/tracking";

export default class ReviewableChatMessage extends Component {
  @service store;

  @cached
  get chatChannel() {
    return this.store.createRecord(
      "chat-channel",
      this.args.reviewable.chat_channel
    );
  }
}
