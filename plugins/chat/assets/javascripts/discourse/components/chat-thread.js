import Component from "@glimmer/component";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default class ChatThreadPanel extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;

  get thread() {
    return this.chat.activeChannel.activeThread;
  }

  get title() {
    if (this.thread.title) {
      this.thread.escapedTitle;
    }

    return I18n.t("chat.threads.op_said");
  }
}
