import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoMembersRoute extends DiscourseRoute {
  afterModel(model) {
    if (!model.isOpen) {
      return this.replaceWith("chat.channel.info.settings");
    }

    if (model.membershipsCount < 1) {
      return this.replaceWith("chat.channel.info");
    }
  }
}
