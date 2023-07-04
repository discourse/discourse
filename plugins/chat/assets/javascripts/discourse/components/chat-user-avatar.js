import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatUserAvatar extends Component {
  @service chat;

  get avatarSize() {
    return this.args.avatarSize || "tiny";
  }

  get isOnline() {
    const users = this.chat.presenceChannel?.users;

    return (
      !!users?.findBy("id", this.args.user?.id) ||
      !!users?.findBy("username", this.args.user?.username)
    );
  }
}
