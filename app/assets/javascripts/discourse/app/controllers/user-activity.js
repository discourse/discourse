import Controller, { inject as controller } from "@ember/controller";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import { exportUserArchive } from "discourse/lib/export-csv";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default Controller.extend({
  dialog: service(),
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

  actions: {
    exportUserArchive() {
      this.dialog.yesNoConfirm({
        message: I18n.t("user.download_archive.confirm"),
        didConfirm: () => exportUserArchive(),
      });
    },
  },
});
