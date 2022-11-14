import Component from "@ember/component";
import { computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatUserAvatar extends Component {
  @service chat;
  tagName = "";

  user = null;

  avatarSize = "tiny";

  @computed("chat.presenceChannel.users.[]", "user.{id,username}")
  get isOnline() {
    const users = this.chat.presenceChannel?.users;

    return (
      !!users?.findBy("id", this.user?.id) ||
      !!users?.findBy("username", this.user?.username)
    );
  }
}
