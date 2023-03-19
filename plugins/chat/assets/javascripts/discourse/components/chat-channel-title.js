import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";

export default class ChatChannelTitle extends Component {
  @service site;

  get multiDm() {
    return this.users.length > 1;
  }

  get users() {
    return this.args.channel?.chatable?.users || [];
  }

  get usernames() {
    return this.users.map((user) => user.username).join(", ");
  }

  get color() {
    return this.args.channel?.chatable?.color;
  }

  get channelColorStyle() {
    if (!this.color) {
      return;
    }

    return htmlSafe(`color: #${this.color}`);
  }

  get showUserStatus() {
    return !!(this.users.length === 1 && this.users[0].status);
  }
}
