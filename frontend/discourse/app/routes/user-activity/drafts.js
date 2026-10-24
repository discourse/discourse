import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserActivityDrafts extends DiscourseRoute {
  @service router;
  @service currentUser;
  @service siteSettings;

  templateName = "user-activity/drafts";

  beforeModel() {
    if (!this.currentUser) {
      return this.router.transitionTo("discovery.latest");
    }
    if (!this.isCurrentUser(this.modelFor("user"))) {
      return this.router.transitionTo(this.routeName, this.currentUser);
    }
  }

  async model() {
    const draftsStream = this.createStream(this.modelFor("user"));
    draftsStream.reset();

    await draftsStream.findItems(this.site);

    return {
      stream: draftsStream,
      emptyState: this.emptyState(),
      showDiscardedLink: this.siteSettings.discarded_drafts_retention_days > 0,
    };
  }

  createStream(user) {
    return user.get("userDraftsStream");
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
