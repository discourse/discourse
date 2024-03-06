import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

// This route is only here as a convenience method for a clean `/c/:channelTitle/:channelId/:messageId/t/:threadId` URL.
// It's not a real route, it just redirects to the real route after setting a param on the controller.
export default class ChatChannelNearMessageWithThread extends DiscourseRoute {
  @service router;
  @service site;

  beforeModel() {
    const channel = this.modelFor("chat-channel");
    const { messageId, threadId } = this.paramsFor(this.routeName);
    this.controllerFor("chat-channel").set("messageId", null);

    if (
      messageId ||
      this.controllerFor("chat-channel").get("targetMessageId")
    ) {
      this.controllerFor("chat-channel").set("targetMessageId", messageId);
    }

    if (threadId && this.site.desktopView) {
      this.router.replaceWith(
        "chat.channel.thread",
        ...channel.routeModels,
        threadId
      );
    }
  }
}
