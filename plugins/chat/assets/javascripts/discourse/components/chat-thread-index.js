import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatThreadIndex extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service chatChannelThreadComposer;
  @service chatChannelThreadIndexPane;

  get channel() {
    return this.chat.activeChannel;
  }
}
