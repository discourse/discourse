import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

// This route is only here as a convenience method for a clean `/c/:channelTitle/:channelId/:messageId` URL.
// It's not a real route, it just redirects to the real route after setting a param on the controller.
export default class ChatChannelNearMessage extends DiscourseRoute {
  @service router;

  beforeModel() {
    const channel = this.modelFor("chat.channel");
    const { messageId } = this.paramsFor(this.routeName);
    this.controllerFor("chat.channel").set("messageId", null);

    if (
      messageId ||
      this.controllerFor("chat.channel").get("targetMessageId")
    ) {
      this.controllerFor("chat.channel").set("targetMessageId", messageId);
    }

    this.router.replaceWith("chat.channel", ...channel.routeModels);
  }
}
