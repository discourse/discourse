import Controller, { inject as controller } from "@ember/controller";
import { service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class UserActivityController extends Controller {
  @service currentUser;
  @controller user;

  userActionType = null;

  @discourseComputed("currentUser.draft_count")
  draftLabel(count) {
    return count > 0
      ? I18n.t("drafts.label_with_count", { count })
      : I18n.t("drafts.label");
  }

  @discourseComputed("model.pending_posts_count")
  pendingLabel(count) {
    return count > 0
      ? I18n.t("pending_posts.label_with_count", { count })
      : I18n.t("pending_posts.label");
  }
}
