import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelLegacyRoute extends DiscourseRoute {
  @service router;

  redirect() {
    const { channelTitle, channelId, messageId } = this.paramsFor(
      this.routeName
    );

    this.router.replaceWith(
      "chat.channel.from-params",
      channelTitle,
      channelId,
      {
        queryParams: { messageId },
      }
    );
  }
}
