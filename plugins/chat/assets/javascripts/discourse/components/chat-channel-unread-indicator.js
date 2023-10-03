import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatChannelUnreadIndicator extends Component {
  @service chat;
  @service site;

  get showUnreadIndicator() {
    return (
      this.args.channel.tracking.unreadCount > 0 ||
      // We want to do this so we don't show a blue dot if the user is inside
      // the channel and a new unread thread comes in.
      (this.chat.activeChannel?.id !== this.args.channel.id &&
        this.args.channel.unreadThreadsCountSinceLastViewed > 0)
    );
  }

  get unreadCount() {
    return this.args.channel.tracking.unreadCount;
  }

  get isUrgent() {
    return (
      this.args.channel.isDirectMessageChannel ||
      this.args.channel.tracking.mentionCount > 0
    );
  }

  get showUnreadCount() {
    return this.args.channel.isDirectMessageChannel || this.isUrgent;
  }
}
