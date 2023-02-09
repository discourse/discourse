import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class UserCardChatButton extends Component {
  @service chat;
  @service appEvents;
  @service router;

  @action
  startChatting() {
    this.router.transitionTo("chat.draft-channel");
    this.appEvents.trigger("card:close");
  }
}
