import Component from "@ember/component";
import { computed } from "@ember/object";
import { isCollapsible } from "discourse/plugins/chat/discourse/components/chat-message-collapser";

export default class ChatMessageText extends Component {
  tagName = "";
  cooked = null;
  uploads = null;
  edited = false;

  @computed("cooked", "uploads.[]")
  get isCollapsible() {
    return isCollapsible(this.cooked, this.uploads);
  }
}
