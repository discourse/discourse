import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ChatNotices extends Component {
  @service("chat-channel-notices-manager") noticesManager;

  get noticesForChannel() {
    return this.noticesManager.notices.filter(
      (notice) => notice.channelId === this.args.channel.id
    );
  }
}
