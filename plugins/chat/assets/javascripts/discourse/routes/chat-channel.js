import DiscourseRoute from "discourse/routes/discourse";
import withChatChannel from "./chat-channel-decorator";
import { inject as service } from "@ember/service";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {
  @service chatThreadsManager;

  beforeModel() {
    this.chatThreadsManager.resetCache();
  }
}
