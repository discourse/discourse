import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ReviewableChatMessage extends Component {
  @service store;

  get chatChannel() {
    return this.store.createRecord(
      "chat-channel",
      this.args.reviewable.chat_channel
    );
  }
}
