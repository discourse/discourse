Discourse.AdminGroupsController = Ember.ArrayController.extend({
  itemController: 'adminGroup',

  edit: function(group){
    this.get('model').select(group);
    group.loadUsers();
  },

  refreshAutoGroups: function(){
    var controller = this;

    this.set('refreshingAutoGroups', true);
    Discourse.ajax('/admin/groups/refresh_automatic_groups', {type: 'POST'}).then(function(){
      controller.set('model', Discourse.Group.findAll());
      controller.set('refreshingAutoGroups',false);
    });
  }
});

Discourse.AdminGroupController = Ember.Controller.extend({

});
