import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import withChatChannel from "./chat-channel-decorator";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {
  @service site;

  redirect(model) {
    if (this.site.mobileView) {
      return;
    }

    const messageId = this.paramsFor("chat.channel.near-message").messageId;
    const threadId = this.paramsFor("chat.channel.thread").threadId;

    if (!messageId && !threadId && model.threadsManager.unreadThreadCount > 0) {
      this.transitionTo("chat.channel.threads", ...model.routeModels);
    }
  }
}
