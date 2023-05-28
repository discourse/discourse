import Component from "@glimmer/component";
import I18n from "I18n";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatThreadHeader extends Component {
  @service currentUser;
  @service router;

  get label() {
    if (this.args.thread) {
      return this.args.thread.escapedTitle;
    } else {
      return I18n.t("chat.threads.list");
    }
  }

  get canChangeThreadSettings() {
    if (!this.args.thread) {
      return false;
    }

    return (
      this.currentUser.staff ||
      this.currentUser.id === this.args.thread.originalMessage.user.id
    );
  }

  @action
  openThreadSettings() {
    const controller = showModal("chat-thread-settings-modal");
    controller.set("thread", this.args.thread);
  }
}
