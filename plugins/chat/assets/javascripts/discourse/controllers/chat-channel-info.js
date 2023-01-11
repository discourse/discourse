import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import { reads } from "@ember/object/computed";
import { computed } from "@ember/object";

export default class ChatChannelInfoIndexController extends Controller {
  @service router;
  @service chat;
  @service chatChannelInfoRouteOriginManager;

  @reads("router.currentRoute.localName") tab;

  @computed("model.{membershipsCount,status,currentUserMembership.following}")
  get tabs() {
    const tabs = [];

    if (!this.model.isDirectMessageChannel) {
      tabs.push("about");
    }

    if (this.model.isOpen && this.model.membershipsCount >= 1) {
      tabs.push("members");
    }

    if (
      this.currentUser?.staff ||
      this.model.currentUserMembership?.following
    ) {
      tabs.push("settings");
    }

    return tabs;
  }
}
