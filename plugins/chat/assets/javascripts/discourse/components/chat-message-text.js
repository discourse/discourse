import Component from "@glimmer/component";
import { isCollapsible } from "discourse/plugins/chat/discourse/components/chat-message-collapser";

export default class ChatMessageText extends Component {
  get isEdited() {
    return this.args.edited ?? false;
  }

  get isCollapsible() {
    return isCollapsible(this.args.cooked, this.args.uploads);
  }
}
