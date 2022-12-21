import { inject as service } from "@ember/service";
import Component from "@glimmer/component";

export default class ChatHeaderIcon extends Component {
  @service currentUser;
  @service site;
  @service chatStateManager;

  get currentUserInDnD() {
    return this.currentUser.isInDoNotDisturb();
  }

  get href() {
    if (this.chatStateManager.isFullPageActive && this.site.mobileView) {
      return "/chat";
    }

    if (this.chatStateManager.isDrawerActive) {
      return "/chat";
    } else {
      return this.chatStateManager.lastKnownChatURL || "/chat";
    }
  }

  get isActive() {
    return (
      this.chatStateManager.isFullPageActive ||
      this.chatStateManager.isDrawerActive
    );
  }
}
