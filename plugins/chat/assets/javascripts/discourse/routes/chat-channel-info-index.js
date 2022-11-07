import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoIndexRoute extends DiscourseRoute {
  afterModel(model) {
    if (model.chatChannel.isDirectMessageChannel) {
      if (model.chatChannel.isOpen && model.chatChannel.membershipsCount >= 1) {
        this.replaceWith("chat.channel.info.members");
      } else {
        this.replaceWith("chat.channel.info.settings");
      }
    } else {
      this.replaceWith("chat.channel.info.about");
    }
  }
}
