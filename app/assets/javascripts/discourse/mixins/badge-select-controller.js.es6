export default Ember.Mixin.create({
  saving: false,
  saved: false,

  selectableUserBadges: function() {
    var items = this.get('filteredList');
    items = _.uniq(items, false, function(e) { return e.get('badge.name'); });
    items.unshiftObject(Em.Object.create({
      badge: Discourse.Badge.create({name: I18n.t('badges.none')})
    }));
    return items;
  }.property('filteredList'),

  savingStatus: function() {
    if (this.get('saving')) {
      return I18n.t('saving');
    } else {
      return I18n.t('save');
    }
  }.property('saving'),

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

  disableSave: Em.computed.alias('saving')
});

