import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class UserCardChatButton extends Component {
  @service chat;
  @service appEvents;
  @service router;

  @action
  startChatting() {
    this.chat
      .upsertDmChannelForUsernames([this.user.username])
      .then((chatChannel) => {
        this.chat.openChannel(chatChannel);
        this.appEvents.trigger("card:close");
      });
  }
}
