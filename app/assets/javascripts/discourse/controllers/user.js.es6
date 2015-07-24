import { exportUserArchive } from 'discourse/lib/export-csv';
import ObjectController from 'discourse/controllers/object';
import CanCheckEmails from 'discourse/mixins/can-check-emails';

export default ObjectController.extend(CanCheckEmails, {
  indexStream: false,
  pmView: false,
  userActionType: null,
  needs: ['user-notifications', 'user-topics-list'],

  viewingSelf: function() {
    return this.get('content.username') === Discourse.User.currentProp('username');
  }.property('content.username'),

  collapsedInfo: Em.computed.not('indexStream'),

  websiteName: function() {
    var website = this.get('model.website');
    if (Em.isEmpty(website)) { return; }
    return website.split("/")[2];
  }.property('model.website'),

  linkWebsite: Em.computed.not('model.isBasic'),

  removeNoFollow: function() {
    return this.get('model.trust_level') > 2 && !this.siteSettings.tl3_links_no_follow;
  }.property('model.trust_level'),

  canSeePrivateMessages: Ember.computed.or('viewingSelf', 'currentUser.admin'),
  canSeeNotificationHistory: Em.computed.alias('canSeePrivateMessages'),

  showBadges: function() {
    return Discourse.SiteSettings.enable_badges && (this.get('content.badge_count') > 0);
  }.property('content.badge_count'),

  privateMessageView: function() {
    return (this.get('userActionType') === Discourse.UserAction.TYPES.messages_sent) ||
           (this.get('userActionType') === Discourse.UserAction.TYPES.messages_received);
  }.property('userActionType'),

  canInviteToForum: function() {
    return Discourse.User.currentProp('can_invite_to_forum');
  }.property(),

  canDeleteUser: function() {
    return this.get('model.can_be_deleted') && this.get('model.can_delete_all_posts');
  }.property('model.can_be_deleted', 'model.can_delete_all_posts'),

  publicUserFields: function() {
    var siteUserFields = this.site.get('user_fields');
    if (!Ember.isEmpty(siteUserFields)) {
      var userFields = this.get('model.user_fields');
      return siteUserFields.filterProperty('show_on_profile', true).sortBy('id').map(function(uf) {
        var val = userFields ? userFields[uf.get('id').toString()] : null;
        if (Ember.isEmpty(val)) {
          return null;
        } else {
          return Ember.Object.create({value: val, field: uf});
        }
      }).compact();
    }
  }.property('model.user_fields.@each.value'),

  privateMessagesActive: Em.computed.equal('pmView', 'index'),
  privateMessagesMineActive: Em.computed.equal('pmView', 'mine'),
  privateMessagesUnreadActive: Em.computed.equal('pmView', 'unread'),

  actions: {
    adminDelete: function() {
      Discourse.AdminUser.find(this.get('username').toLowerCase()).then(function(user){
        user.destroy({deletePosts: true});
      });
    },

    exportUserArchive: function() {
      bootbox.confirm(
        I18n.t("admin.export_csv.user_archive_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(confirmed) {
          if (confirmed) {
            exportUserArchive();
          }
        }
      );
    }
  }
});
