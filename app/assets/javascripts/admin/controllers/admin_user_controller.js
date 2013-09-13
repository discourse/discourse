/**
  A controller related to viewing a user in the admin section

  @class AdminUserController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUserController = Discourse.ObjectController.extend({
  editingTitle: false,

  toggleTitleEdit: function() {
    this.set('editingTitle', !this.editingTitle);
  },

  saveTitle: function() {
    Discourse.ajax("/users/" + this.get('username').toLowerCase(), {
      data: {title: this.get('title')},
      type: 'PUT'
    }).then(null, function(e){
      bootbox.alert(I18n.t("generic_error_with_reason", {error: "http: " + e.status + " - " + e.body}));
    });

    this.toggleTitleEdit();
  },

  showApproval: function() {
    return Discourse.SiteSettings.must_approve_users;
  }.property()
});
