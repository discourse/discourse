import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default class SidebarChannels extends Component {
  @service chat;
  @service router;
  tagName = "";
  toggleSection = null;

  @computed("chat.userCanChat")
  get isDisplayed() {
    return this.chat.userCanChat;
  }

  @action
  switchChannel(channel) {
    this.chat.openChannel(channel);
  }
}
