import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatThreadHeaderUnreadIndicator extends Component {
  @service currentUser;

  get currentUserInDnD() {
    return this.currentUser.isInDoNotDisturb();
  }

  get unreadCount() {
    return this.args.channel.threadsManager.unreadThreadCount;
  }

  get showUnreadIndicator() {
    return !this.currentUserInDnD && this.unreadCount > 0;
  }

  get unreadCountLabel() {
    return this.unreadCount > 99 ? "99+" : this.unreadCount;
  }
}
