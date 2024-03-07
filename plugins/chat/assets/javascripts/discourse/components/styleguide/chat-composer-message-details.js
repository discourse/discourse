import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatComposerMessageDetails extends Component {
  @service site;
  @service session;
  @service keyValueStore;
  @service currentUser;

  @cached
  get message() {
    return fabricators.message({ user: this.currentUser });
  }

  @action
  toggleMode() {
    if (this.message.editing) {
      this.message.editing = false;
      this.message.inReplyTo = fabricators.message();
    } else {
      this.message.editing = true;
      this.message.inReplyTo = null;
    }
  }
}
