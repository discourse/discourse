import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatThreadHeaderUnreadIndicator extends Component {
  @service chatTrackingStateManager;

  get showUnreadIndicator() {
    return this.args.channel.threadTrackingOverview.length > 0;
  }

  get unreadCounter() {
    const unreadThreads = this.args.channel.threadTrackingOverview.length;
    if (unreadThreads > 99) {
      return "99+";
    }

    return unreadThreads;
  }
}
