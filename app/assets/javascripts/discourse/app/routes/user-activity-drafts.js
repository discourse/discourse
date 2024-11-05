import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class UserActivityDrafts extends DiscourseRoute {
  templateName = "user/stream";

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
    const title = I18n.t("user_activity.no_drafts_title");
    const body = I18n.t("user_activity.no_drafts_body");
    return { title, body };
  }

  activate() {
    this.appEvents.on("draft:destroyed", this, this.refresh);
  }

  deactivate() {
    this.appEvents.off("draft:destroyed", this, this.refresh);
  }

  titleToken() {
    return I18n.t("user_action_groups.15");
  }
}
