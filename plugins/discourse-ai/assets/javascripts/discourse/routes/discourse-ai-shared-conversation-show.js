import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiSharedConversationShowRoute extends DiscourseRoute {
  @service currentUser;

  beforeModel(transition) {
    if (this.currentUser?.user_option?.external_links_in_new_tab) {
      window.open(transition.intent.url, "_blank");
    } else {
      this.redirect(transition.intent.url);
    }
    transition.abort();
  }

  redirect(url) {
    window.location = url;
  }
}
