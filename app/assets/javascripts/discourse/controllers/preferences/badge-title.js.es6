/**
  Controller for selecting a badge to use as your title.

  @class PreferencesBadgeTitleController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
export default Ember.ArrayController.extend({
  saving: false,
  saved: false,

  savingStatus: function() {
    if (this.get('saving')) {
      return I18n.t('saving');
    } else {
      return I18n.t('save');
    }
  }.property('saving'),

  selectableUserBadges: Em.computed.filterBy('model', 'badge.allow_title', true),

  selectedUserBadge: function() {
    var selectedUserBadgeId = parseInt(this.get('selectedUserBadgeId'));
    var selectedUserBadge = null;
    this.get('selectableUserBadges').forEach(function(userBadge) {
      if (userBadge.get('id') === selectedUserBadgeId) {
        selectedUserBadge = userBadge;
      }
    });
    return selectedUserBadge;
  }.property('selectedUserBadgeId'),

  titleNotChanged: Discourse.computed.propertyEqual('user.title', 'selectedUserBadge.badge.name'),

  disableSave: Em.computed.or('saving', 'titleNotChanged'),

  actions: {
    save: function() {
      var self = this;

      self.set('saved', false);
      self.set('saving', true);

      Discourse.ajax("/users/" + self.get('user.username_lower') + "/preferences/badge_title", {
        type: "PUT",
        data: {
          user_badge_id: self.get('selectedUserBadgeId')
        }
      }).then(function() {
        self.set('saved', true);
        self.set('saving', false);
        self.set('user.title', self.get('selectedUserBadge.badge.name'));
      }, function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    }
  }
});
