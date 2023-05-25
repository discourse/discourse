import Component from "@glimmer/component";

export default class ChatThreadHeaderUnreadIndicator extends Component {
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
