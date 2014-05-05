Discourse.AdminGroupsController = Ember.ArrayController.extend({
  sortProperties: ['name'],

  refreshingAutoGroups: false,

  actions: {
    refreshAutoGroups: function(){
      var self = this,
          groups = this.get('model');

      self.set('refreshingAutoGroups', true);
      this.transitionToRoute('adminGroups.index').then(function() {
        Discourse.ajax('/admin/groups/refresh_automatic_groups', {type: 'POST'}).then(function() {
          return Discourse.Group.findAll().then(function(newGroups) {
            groups.clear();
            groups.addObjects(newGroups);
          }).finally(function() {
            self.set('refreshingAutoGroups', false);
          });
        });
      });
    }
  }

});

