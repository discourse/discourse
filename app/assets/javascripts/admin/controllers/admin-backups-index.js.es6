import { ajax } from 'discourse/lib/ajax';
export default Ember.ArrayController.extend({
  needs: ["adminBackups"],
  status: Ember.computed.alias("controllers.adminBackups"),

  uploadLabel: function() { return I18n.t("admin.backups.upload.label"); }.property(),

  restoreTitle: function() {
    if (!this.get('status.model.allowRestore')) {
      return "admin.backups.operations.restore.is_disabled";
    } else if (this.get("status.model.isOperationRunning")) {
      return "admin.backups.operations.is_running";
    } else {
      return "admin.backups.operations.restore.title";
    }
  }.property("status.model.{allowRestore,isOperationRunning}"),

  actions: {

    toggleReadOnlyMode() {
      var self = this;
      if (!this.site.get("isReadOnly")) {
        bootbox.confirm(
          I18n.t("admin.backups.read_only.enable.confirm"),
          I18n.t("no_value"),
          I18n.t("yes_value"),
          function(confirmed) {
            if (confirmed) {
              Discourse.User.currentProp("hideReadOnlyAlert", true);
              self._toggleReadOnlyMode(true);
            }
          }
        );
      } else {
        this._toggleReadOnlyMode(false);
      }
    }

  },

  _toggleReadOnlyMode(enable) {
    var site = this.site;
    ajax("/admin/backups/readonly", {
      type: "PUT",
      data: { enable: enable }
    }).then(function() {
      site.set("isReadOnly", enable);
    });
  }
});
