import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import { getOwner } from "@ember/application";

export default class ChatMessageActionsDesktop extends Component {
  @service chatStateManager;

  get messageInteractor() {
    return new ChatMessageInteractor(
      getOwner(this),
      this.args.message,
      this.args.context
    );
  }
}
