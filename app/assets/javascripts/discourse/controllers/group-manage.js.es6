import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  @computed("model.automatic")
  tabs(automatic) {
    const defaultTabs = [
      { route: 'group.manage.profile', title: 'groups.manage.profile.title' },
    ];

    if (!automatic) {
      defaultTabs.push(
        { route: 'group.manage.members', title: 'groups.manage.members.title' }
      );

      defaultTabs.push(
        { route: 'group.manage.logs', title: 'groups.manage.logs.title' },
      );
    }

    return defaultTabs;
  },
});
