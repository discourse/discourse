import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class ChatChannelTitle extends Component {
  get users() {
    return this.args.channel.chatable.users;
  }

  get multiDm() {
    return this.users.length > 1;
  }

  get usernames() {
    return this.users.mapBy("username").join(", ");
  }

  get channelColorStyle() {
    return htmlSafe(`color: #${this.args.channel.chatable.color}`);
  }

  get showUserStatus() {
    return !!(this.users.length === 1 && this.users[0].status);
  }
}
