import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatThreadHeaderUnreadIndicator extends Component {
  @service chatTrackingStateManager;

  get showUnreadIndicator() {
    return this.channelUnreadThreadCount > 0;
  }

  get channelUnreadThreadCount() {
    return this.chatTrackingStateManager.unreadThreadCountForChannel(
      this.args.channel
    );
  }
}
