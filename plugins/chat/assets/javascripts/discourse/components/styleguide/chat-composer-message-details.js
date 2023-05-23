import Component from "@glimmer/component";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { action } from "@ember/object";
import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

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
