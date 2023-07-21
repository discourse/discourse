import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoAboutRoute extends DiscourseRoute {
  afterModel(model) {
    if (model.isDirectMessageChannel) {
      this.replaceWith("chat.channel.info.index");
    }
  }
}
