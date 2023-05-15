import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatChannelUnreadIndicator extends Component {
  @service chatTrackingState;

  get channelUnreadCount() {
    return this.chatTrackingState.getChannelState(this.args.channel.id)
      .unreadCount;
  }

  get channelMentionCount() {
    return this.chatTrackingState.getChannelState(this.args.channel.id)
      .unreadCount;
  }
}
