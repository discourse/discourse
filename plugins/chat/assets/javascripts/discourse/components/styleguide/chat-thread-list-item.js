import Component from "@glimmer/component";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { inject as service } from "@ember/service";

export default class ChatStyleguideChatThreadListItem extends Component {
  @service currentUser;

  thread = fabricators.thread();
}
