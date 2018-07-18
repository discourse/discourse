import ApiKey from "admin/models/api-key";

export default Ember.Controller.extend({
  actions: {
    generateMasterKey() {
      ApiKey.generateMasterKey().then(key => this.get("model").pushObject(key));
    },

    regenerateKey(key) {
      bootbox.confirm(
        I18n.t("admin.api.confirm_regen"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            key.regenerate();
          }
        }
      );
    },

    revokeKey(key) {
      bootbox.confirm(
        I18n.t("admin.api.confirm_revoke"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            key.revoke().then(() => this.get("model").removeObject(key));
          }
        }
      );
    }
  },

  // Has a master key already been generated?
  hasMasterKey: function() {
    return !!this.get("model").findBy("user", null);
  }.property("model.[]")
});
