import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatChannelCard extends Component {
  @service chat;
  tagName = "";

  @action
  afterMembershipToggle() {
    this.chat.forceRefreshChannels();
  }
}
