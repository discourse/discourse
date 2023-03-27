import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { computed } from "@ember/object";
import { gt, reads } from "@ember/object/computed";

export default class ChatChannelTitle extends Component {
  tagName = "";
  channel = null;

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
}
