import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { escapeExpression } from "discourse/lib/utilities";

export default class ChatMessageThreadIndicator extends Component {
  @service site;

  get threadTitle() {
    return escapeExpression(this.args.message.threadTitle);
  }
}
