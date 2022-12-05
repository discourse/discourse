import Controller from "@ember/controller";
import { inject as service } from "@ember/service";

export default class ChatController extends Controller {
  @service chat;

  get shouldUseChatSidebar() {
    if (this.site.mobileView) {
      return false;
    }

    if (this.shouldUseCoreSidebar) {
      return false;
    }

    return true;
  }

  get shouldUseCoreSidebar() {
    return (
      this.siteSettings.enable_sidebar &&
      this.siteSettings.enable_experimental_sidebar_hamburger
    );
  }
}
