import DiscourseRoute from "discourse/routes/discourse";
import withChatChannel from "./chat-channel-decorator";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {}
