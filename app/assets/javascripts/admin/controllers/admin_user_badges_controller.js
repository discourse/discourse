/**
  This controller supports the interface for granting and revoking badges from
  individual users.

  @class AdminUserBadgesController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUserBadgesController = Ember.ArrayController.extend({
  needs: ["adminUser"],
  user: Em.computed.alias('controllers.adminUser'),
  sortProperties: ['granted_at'],
  sortAscending: false,

  actions: {

    /**
      Grant the selected badge to the user.

      @method grantBadge
      @param {Integer} badgeId id of the badge we want to grant.
    **/
    grantBadge: function(badgeId) {
      var self = this;
      Discourse.UserBadge.grant(badgeId, this.get('user.username')).then(function(userBadge) {
        self.pushObject(userBadge);
      }, function() {
        // Failure
        bootbox.alert(I18n.t('generic_error'));
      });
    },

    /**
      Revoke the selected userBadge.

      @method revokeBadge
      @param {Discourse.UserBadge} userBadge the `Discourse.UserBadge` instance that needs to be revoked.
    **/
    revokeBadge: function(userBadge) {
      var self = this;
      return bootbox.confirm(I18n.t("admin.badges.revoke_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          userBadge.revoke().then(function() {
            self.get('model').removeObject(userBadge);
          });
        }
      });
    }

  }
});
