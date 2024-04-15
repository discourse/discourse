import Component from "@glimmer/component";
import { getOwner } from "@ember/application";
import { service } from "@ember/service";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatThreadListItem extends Component {
  @service currentUser;

  thread = new ChatFabricators(getOwner(this)).thread();
}
