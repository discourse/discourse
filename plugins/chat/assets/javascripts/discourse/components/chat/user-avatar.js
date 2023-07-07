import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatUserAvatar extends Component {
  @service chat;

  get avatarSize() {
    return this.args.avatarSize || "tiny";
  }

  get showPresence() {
    return this.args.showPresence ?? true;
  }

  get isOnline() {
    const users = (this.args.chat || this.chat).presenceChannel?.users;

    return (
      this.showPresence &&
      !!users?.find(
        ({ id, username }) =>
          this.args.user?.id === id || this.args.user?.username === username
      )
    );
  }
}
