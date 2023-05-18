import Component from "@glimmer/component";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { action } from "@ember/object";

export default class ChatThreadListItem extends Component {
  @service currentUser;
  @service router;

  get title() {
    return (
      this.args.thread.escapedTitle ||
      `${I18n.t("chat.thread.default_title", {
        thread_id: this.args.thread.id,
      })}`
    );
  }

  get canChangeThreadSettings() {
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

  @action
  openThread(thread) {
    this.router.transitionTo("chat.channel.thread", ...thread.routeModels);
  }
}
