import { ajax } from 'discourse/lib/ajax';
export default Ember.ArrayController.extend({
  sortProperties: ['name'],
  refreshingAutoGroups: false,
  isAuto: function(){
    return this.get('type') === 'automatic';
  }.property('type'),

  actions: {
    refreshAutoGroups: function(){
      var self = this;
      this.set('refreshingAutoGroups', true);
      ajax('/admin/groups/refresh_automatic_groups', {type: 'POST'}).then(function() {
        self.transitionToRoute("adminGroupsType", "automatic").then(function() {
          self.set('refreshingAutoGroups', false);
        });
      });
    }
  }
});
