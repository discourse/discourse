import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserActivityDrafts extends DiscourseRoute {
  @service router;
  @service currentUser;

  templateName = "user/stream";

  beforeModel() {
    if (!this.currentUser) {
      return this.router.transitionTo("discovery.latest");
    }
    if (!this.isCurrentUser(this.modelFor("user"))) {
      return this.router.transitionTo("userActivity.drafts", this.currentUser);
    }
  }

  async model() {
    const user = this.modelFor("user");
    const draftsStream = user.get("userDraftsStream");
    draftsStream.reset();

    await draftsStream.findItems(this.site);

    return {
      stream: draftsStream,
      emptyState: this.emptyState(),
    };
  }

  emptyState() {
    const title = i18n("user_activity.no_drafts_title");
    const body = i18n("user_activity.no_drafts_body");
    return { title, body };
  }

  activate() {
    this.appEvents.on("draft:destroyed", this, this.refresh);
  }

  deactivate() {
    this.appEvents.off("draft:destroyed", this, this.refresh);
  }

  titleToken() {
    return i18n("user_action_groups.15");
  }
}
