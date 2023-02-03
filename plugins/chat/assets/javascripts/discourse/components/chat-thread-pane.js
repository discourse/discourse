import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatThreadPane extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;

  channel = null;
  thread = null;

  @action
  closeThread() {
    return this.router.transitionTo("chat.channel", {
      channelId: this.args.channel.id,
    });
  }
}
