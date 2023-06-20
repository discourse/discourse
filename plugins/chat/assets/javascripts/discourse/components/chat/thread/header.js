import Component from "@glimmer/component";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatThreadHeader extends Component {
  @service currentUser;
  @service router;
  @service chatStateManager;
  @service chatHistory;
  @service site;

  get backLinkRoute() {
    if (
      this.chatHistory.previousRoute?.name === "chat.channel.index" &&
      this.site.mobileView
    ) {
      return "chat.channel.index";
    }

    return "chat.channel.threads";
  }

  get backLinkModels() {
    if (
      this.chatHistory.previousRoute?.name === "chat.channel.index" &&
      this.site.mobileView
    ) {
      return this.args.channel.routeModels;
    }

    return [];
  }

  get label() {
    return this.args.thread.escapedTitle;
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
