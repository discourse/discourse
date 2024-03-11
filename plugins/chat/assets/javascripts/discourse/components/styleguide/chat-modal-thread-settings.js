import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatModalThreadSettings from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalThreadSettings extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalThreadSettings, {
      model: fabricators.thread(),
    });
  }
}
