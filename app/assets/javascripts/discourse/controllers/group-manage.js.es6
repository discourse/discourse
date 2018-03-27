export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  tabs: [
    { route: 'group.manage.profile', title: 'groups.manage.profile.title' },
    { route: 'group.manage.members', title: 'groups.manage.members.title' },
    { route: 'group.manage.logs', title: 'groups.manage.logs.title' },
  ],
});
