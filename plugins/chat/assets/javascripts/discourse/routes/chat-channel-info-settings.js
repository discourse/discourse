import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoSettingsRoute extends DiscourseRoute {
  afterModel(model) {
    if (!this.currentUser?.staff && !model.currentUserMembership?.following) {
      this.replaceWith("chat.channel.info");
    }
  }
}
