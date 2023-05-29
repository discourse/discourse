import Component from "@glimmer/component";

export default class ChatThreadHeaderUnreadIndicator extends Component {
  get unreadCount() {
    return this.args.channel.unreadThreadCount;
  }

  get showUnreadIndicator() {
    return this.unreadCount > 0;
  }

  get unreadCountLabel() {
    return this.unreadCount > 99 ? "99+" : this.unreadCount;
  }
}
