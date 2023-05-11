import DiscourseRoute from "discourse/routes/discourse";

export default class ChatBrowseIndexRoute extends DiscourseRoute {
  afterModel() {
    if (!this.siteSettings.chat_allow_archiving_channels) {
      this.replaceWith("chat.browse");
    }
  }
}
