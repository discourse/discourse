import { exportUserArchive } from "discourse/lib/export-csv";

export default Ember.Controller.extend({
  application: Ember.inject.controller(),
  user: Ember.inject.controller(),
  userActionType: null,

  canDownloadPosts: Ember.computed.alias("user.viewingSelf"),

  _showFooter: function() {
    var showFooter;
    if (this.get("userActionType")) {
      const stat = _.find(this.get("model.stats"), {
        action_type: this.get("userActionType")
      });
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
