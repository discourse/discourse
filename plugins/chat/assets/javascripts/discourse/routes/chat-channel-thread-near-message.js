import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

// This route is only here as a convenience method for a clean `/c/:channelTitle/:channelId/t/:threadId/:messageId` URL.
// It's not a real route, it just redirects to the real route after setting a param on the controller.
export default class ChatChannelThreadNearMessage extends DiscourseRoute {
  @service router;

  beforeModel() {
    const thread = this.modelFor("chat-channel-thread");
    const { messageId } = this.paramsFor(this.routeName);

    if (
      messageId ||
      this.controllerFor("chat-channel-thread").get("targetMessageId")
    ) {
      this.controllerFor("chat-channel-thread").set(
        "targetMessageId",
        messageId
      );
    }

    this.router.replaceWith("chat.channel.thread", ...thread.routeModels);
  }
}
