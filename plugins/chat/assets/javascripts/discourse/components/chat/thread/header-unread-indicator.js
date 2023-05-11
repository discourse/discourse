import Component from "@glimmer/component";

export default class ChatThreadHeaderUnreadIndicator extends Component {
  get showUrgentIndicator() {
    return this.args.channel.threadUnreadUrgentCount > 0;
  }

  get showUnreadIndicator() {
    return this.args.channel.currentUserMembership.threadUnreadCount > 0;
  }
}
