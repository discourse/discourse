import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatThreadHeaderUnreadIndicator extends Component {
  @service chatTrackingStateManager;

  get showUnreadIndicator() {
    return this.args.channel.unreadThreadCount > 0;
  }

  get unreadCountLabel() {
    if (this.args.channel.unreadThreadCount > 99) {
      return "99+";
    }

    return this.args.channel.unreadThreadCount;
  }
}
