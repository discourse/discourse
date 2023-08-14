import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import Component from "@glimmer/component";
import ChatModalThreadSettings from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatStyleguideChatModalThreadSettings extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalThreadSettings, {
      model: fabricators.thread(),
    });
  }
}
