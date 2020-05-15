import I18n from "I18n";
import { alias } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import Controller, { inject as controller } from "@ember/controller";
import { exportUserArchive } from "discourse/lib/export-csv";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  application: controller(),
  user: controller(),
  router: service(),
  userActionType: null,

  canDownloadPosts: alias("user.viewingSelf"),

  @observes("userActionType", "model.stream.itemsLoaded")
  _showFooter: function() {
    var showFooter;
    if (this.userActionType) {
      const stat = (this.get("model.stats") || []).find(
        s => s.action_type === this.userActionType
      );
      showFooter = stat && stat.count <= this.get("model.stream.itemsLoaded");
    } else {
      showFooter =
        this.get("model.statsCountNonPM") <=
        this.get("model.stream.itemsLoaded");
    }
    this.set("application.showFooter", showFooter);
  },

  actions: {
    exportUserArchive() {
      bootbox.confirm(
        I18n.t("user.download_archive.confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        confirmed => (confirmed ? exportUserArchive() : null)
      );
    }
  }
});
