import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatUserCardButton extends Component {
  @service chat;
  @service appEvents;
  @service router;

  get shouldRender() {
    return this.chat.userCanDirectMessage && !this.args.user.suspended;
  }

  @action
  startChatting() {
    return this.chat
      .upsertDmChannelForUsernames([this.args.user.username])
      .then((channel) => {
        this.router.transitionTo("chat.channel", ...channel.routeModels);
        this.appEvents.trigger("card:close");
      });
  }
}
