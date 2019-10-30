import { alias } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { exportUserArchive } from "discourse/lib/export-csv";

export default Controller.extend({
  application: inject(),
  router: service(),
  user: inject(),
  userActionType: null,

  canDownloadPosts: alias("user.viewingSelf"),

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
  }.observes("userActionType", "model.stream.itemsLoaded"),

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
