import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatThreadList extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service chatChannelThreadComposer;
  @service chatChannelThreadListPane;

  get channel() {
    return this.chat.activeChannel;
  }
}
