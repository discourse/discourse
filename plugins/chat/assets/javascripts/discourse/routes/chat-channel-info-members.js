import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoMembersRoute extends DiscourseRoute {
  afterModel(model) {
    if (!model.chatChannel.isOpen) {
      this.replaceWith("chat.channel.info.settings");
    }
  }
}
