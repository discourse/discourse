import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelLegacyRoute extends DiscourseRoute {
  @service router;

  redirect() {
    const { channelTitle, channelId, messageId } = this.paramsFor(
      this.routeName
    );

    this.router.replaceWith("chat.channel", channelTitle, channelId, {
      queryParams: { messageId },
    });
  }
}
