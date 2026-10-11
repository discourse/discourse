import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserActivitySharedAiArtifacts extends DiscourseRoute {
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
    return ajax("/discourse-ai/ai-bot/artifact-shares.json");
  }

  titleToken() {
    return i18n("discourse_ai.ai_artifact.shared_artifacts");
  }
}
