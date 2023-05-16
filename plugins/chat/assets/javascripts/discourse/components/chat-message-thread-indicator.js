import Component from "@glimmer/component";
import { escapeExpression } from "discourse/lib/utilities";

export default class ChatMessageThreadIndicator extends Component {
  get threadTitle() {
    return escapeExpression(this.args.message.threadTitle);
  }
}
