import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  @computed("model.automatic")
  tabs(automatic) {
    const defaultTabs = [
      { route: 'group.manage.profile', title: 'groups.manage.profile.title' },
      { route: 'group.manage.logs', title: 'groups.manage.logs.title' },
    ];

    if (!automatic) {
      defaultTabs.splice(1, 0,
        { route: 'group.manage.members', title: 'groups.manage.members.title' }
      );
    }

    return defaultTabs;
  },
});
