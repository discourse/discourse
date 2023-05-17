import Component from "@glimmer/component";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { inject as service } from "@ember/service";

export default class ChatStyleguideChatThreadOriginalMessage extends Component {
  @service currentUser;

  message = fabricators.message({ user: this.currentUser });
}
