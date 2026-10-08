import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserActivitySharedAiConversations extends DiscourseRoute {
  @service currentUser;
  @service router;
  @service siteSettings;

  beforeModel() {
    if (
      !this.siteSettings.discourse_ai_enabled ||
      !this.currentUser ||
      this.modelFor("user")?.id !== this.currentUser.id
    ) {
      return this.router.replaceWith("userActivity.index");
    }
  }

  model() {
    return ajax("/discourse-ai/ai-bot/shared-ai-conversations.json");
  }

  titleToken() {
    return i18n("discourse_ai.shared_ai_conversations.title");
  }
}
