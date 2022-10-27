import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { reads } from "@ember/object/computed";

export default class ChatChannelInfoIndexController extends Controller {
  @service router;
  @service chat;
  @service chatChannelInfoRouteOriginManager;

  @reads("router.currentRoute.localName") tab;

  @computed("model.chatChannel.{membershipsCount,status}")
  get tabs() {
    const tabs = [];

    if (!this.model.chatChannel.isDirectMessageChannel) {
      tabs.push("about");
    }

    if (
      this.model.chatChannel.isOpen &&
      this.model.chatChannel.membershipsCount >= 1
    ) {
      tabs.push("members");
    }

    tabs.push("settings");

    return tabs;
  }

  @action
  switchChannel(channel) {
    return this.chat.openChannel(channel);
  }
}
