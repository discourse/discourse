Discourse.BadgeGrouping= Discourse.Model.extend({
  i18nNameKey: function() {
    return this.get('name').toLowerCase().replace(/\s/g, '_');
  }.property('name'),

  displayName: function(){
    var i18nKey = "badges.badge_grouping." + this.get('i18nNameKey') + ".name";
    return I18n.t(i18nKey, {defaultValue: this.get('name')});
  }.property()
});
