import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatNotices extends Component {
  @service("chat-channel-pane-subscriptions-manager") subscriptionsManager;

  get noticesForChannel() {
    return this.subscriptionsManager.notices.filter(
      (notice) => notice.channelId === this.args.channel.id
    );
  }

  @action
  clearNotice(notice) {
    this.subscriptionsManager.clearNotice(notice);
  }
}
