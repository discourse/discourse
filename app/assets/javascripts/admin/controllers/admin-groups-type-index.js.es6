import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  adminGroupsType: Ember.inject.controller(),
  sortedGroups: Ember.computed.alias("adminGroupsType.sortedGroups"),

  @computed("sortedGroups")
  messageKey(sortedGroups) {
    return `admin.groups.${sortedGroups.length > 0 ? 'none_selected' : 'no_custom_groups'}`;
  }
});
