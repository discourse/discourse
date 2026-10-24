import UserDraftsStream from "discourse/models/user-drafts-stream";
import UserActivityDrafts from "discourse/routes/user-activity/drafts";
import { i18n } from "discourse-i18n";

export default class UserActivityDiscardedDrafts extends UserActivityDrafts {
  createStream(user) {
    return UserDraftsStream.create({ user, discarded: true });
  }

  async model() {
    const model = await super.model(...arguments);
    model.discarded = true;
    model.description = i18n("drafts.discarded.description", {
      count: this.siteSettings.discarded_drafts_retention_days,
    });
    return model;
  }

  emptyState() {
    return {
      title: i18n("user_activity.no_discarded_drafts_title"),
      body: i18n("user_activity.no_discarded_drafts_body"),
    };
  }

  titleToken() {
    return i18n("drafts.discarded.title");
  }
}
