import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import getURL from "discourse-common/lib/get-url";

export default class ChatHeaderIcon extends Component {
  @service currentUser;
  @service site;
  @service chatStateManager;
  @service router;

  get currentUserInDnD() {
    return this.args.currentUserInDnD || this.currentUser.isInDoNotDisturb();
  }

  get isActive() {
    return (
      this.args.isActive ||
      this.chatStateManager.isFullPageActive ||
      this.chatStateManager.isDrawerActive
    );
  }

  get href() {
    if (this.chatStateManager.isFullPageActive) {
      if (this.site.mobileView) {
        return getURL("/chat");
      } else {
        return getURL(this.router.currentURL);
      }
    }

    if (this.chatStateManager.isDrawerActive) {
      return getURL("/chat");
    }

    return getURL(this.chatStateManager.lastKnownChatURL || "/chat");
  }
}
