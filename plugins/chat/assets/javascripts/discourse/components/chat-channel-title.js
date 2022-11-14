import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { computed } from "@ember/object";
import { gt, reads } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default class ChatChannelTitle extends Component {
  tagName = "";
  channel = null;
  unreadIndicator = false;

  @reads("channel.chatable.users.[]") users;
  @gt("users.length", 1) multiDm;

  @computed("users")
  get usernames() {
    return this.users.mapBy("username").join(", ");
  }

  @computed("channel.chatable.color")
  get channelColorStyle() {
    return htmlSafe(`color: #${this.channel.chatable.color}`);
  }

  @computed(
    "channel.chatable.users.length",
    "channel.chatable.users.@each.status"
  )
  get showUserStatus() {
    return !!(
      this.channel.chatable.users.length === 1 &&
      this.channel.chatable.users[0].status
    );
  }

  @discourseComputed(
    "currentUser.chat_channel_tracking_state.@each.{last_message}",
    "channel.id"
  )
  channelTrackingState(state, channelId) {
    return state?.[channelId];
  }

  @discourseComputed("channelTrackingState.last_message", "channel")
  lastMessage(lastMessage, channel) {
    if (!channel) {
      return;
    }
    return lastMessage?.message;
  }
}
