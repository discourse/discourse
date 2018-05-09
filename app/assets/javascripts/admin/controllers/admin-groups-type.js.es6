import { ajax } from 'discourse/lib/ajax';
export default Ember.Controller.extend({
  sortedGroups: Ember.computed.sort('model', 'groupSorting'),
  groupSorting: ['name'],

  refreshingAutoGroups: false,

  isAuto: Ember.computed.equal('type', 'automatic'),

  actions: {
    refreshAutoGroups() {
      this.set('refreshingAutoGroups', true);
      ajax('/admin/groups/refresh_automatic_groups', {type: 'POST'}).then(() => {
        this.transitionToRoute("adminGroupsType", "automatic").then(() => {
          this.set('refreshingAutoGroups', false);
        });
      });
    }
  }
});
