/**
  A controller related to viewing a user in the admin section

  @class AdminUserController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUserController = Discourse.ObjectController.extend({
  editingTitle: false,

  showApproval: function() {
    return Discourse.SiteSettings.must_approve_users;
  }.property(),

  actions: {
    toggleTitleEdit: function() {
      this.toggleProperty('editingTitle');
    },

    saveTitle: function() {
      Discourse.ajax("/users/" + this.get('username').toLowerCase(), {
        data: {title: this.get('title')},
        type: 'PUT'
      }).then(null, function(e){
        bootbox.alert(I18n.t("generic_error_with_reason", {error: "http: " + e.status + " - " + e.body}));
      });

      this.send('toggleTitleEdit');
    },

    generateApiKey: function() {
      this.get('model').generateApiKey();
    },

    regenerateApiKey: function() {
      var self = this;
      bootbox.confirm(I18n.t("admin.api.confirm_regen"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          self.get('model').generateApiKey();
        }
      });
    },

    revokeApiKey: function() {
      var self = this;
      bootbox.confirm(I18n.t("admin.api.confirm_revoke"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          self.get('model').revokeApiKey();
        }
      });
    }
  }

});
