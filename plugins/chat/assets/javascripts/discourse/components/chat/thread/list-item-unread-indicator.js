import Component from "@glimmer/component";

export default class ChatThreadListItemUnreadIndicator extends Component {
  get showUnreadIndicator() {
    return this.args.thread.tracking.unreadCount > 0;
  }

  get unreadCountLabel() {
    if (this.args.thread.tracking.unreadCount > 99) {
      return "99+";
    }

    return this.args.thread.tracking.unreadCount;
  }
}
