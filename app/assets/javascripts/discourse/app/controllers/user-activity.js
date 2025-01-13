import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class UserActivityController extends Controller {
  @service currentUser;
  @controller user;

  @tracked userActionType = null;

  @discourseComputed("currentUser.draft_count")
  draftLabel(count) {
    return count > 0
      ? i18n("drafts.label_with_count", { count })
      : i18n("drafts.label");
  }

  @discourseComputed("model.pending_posts_count")
  pendingLabel(count) {
    return count > 0
      ? i18n("pending_posts.label_with_count", { count })
      : i18n("pending_posts.label");
  }
}
