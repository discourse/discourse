import Component from "@glimmer/component";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatThreadOriginalMessage extends Component {
  message = fabricators.message();
}
