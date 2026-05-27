import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class UserActivityController extends Controller {
  @service currentUser;
  @controller user;

  @tracked userActionType = null;

  @computed("currentUser.draft_count")
  get draftLabel() {
    return this.currentUser?.draft_count > 0
      ? i18n("drafts.label_with_count", {
          count: this.currentUser?.draft_count,
        })
      : i18n("drafts.label");
  }

  @computed("model.pending_posts_count")
  get pendingLabel() {
    return this.model?.pending_posts_count > 0
      ? i18n("pending_posts.label_with_count", {
          count: this.model?.pending_posts_count,
        })
      : i18n("pending_posts.label");
  }
}
