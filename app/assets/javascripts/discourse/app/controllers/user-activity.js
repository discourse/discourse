import Controller, { inject as controller } from "@ember/controller";
import { alias } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default Controller.extend({
  currentUser: service(),
  user: controller(),
  userActionType: null,

  canDownloadPosts: alias("user.viewingSelf"),

  @discourseComputed("currentUser.draft_count")
  draftLabel(count) {
    return count > 0
      ? I18n.t("drafts.label_with_count", { count })
      : I18n.t("drafts.label");
  },

  @discourseComputed("model.pending_posts_count")
  pendingLabel(count) {
    return count > 0
      ? I18n.t("pending_posts.label_with_count", { count })
      : I18n.t("pending_posts.label");
  },
});
