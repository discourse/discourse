import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserActivitySharedAiConversations extends DiscourseRoute {
  @service currentUser;
  @service router;
  @service siteSettings;

  beforeModel() {
    const user = this.modelFor("user");
    if (
      !this.siteSettings.discourse_ai_enabled ||
      !this.currentUser ||
      !user ||
      !Number.isInteger(user.id) ||
      user.id <= 0 ||
      (!this.currentUser.admin && user.id !== this.currentUser.id)
    ) {
      return this.router.replaceWith("userActivity.index");
    }
  }

  model() {
    return ajax("/discourse-ai/ai-bot/shared-ai-conversations.json", {
      data: { user_id: this.modelFor("user").id },
    });
  }

  titleToken() {
    return i18n("discourse_ai.shared_ai_conversations.title");
  }
}
