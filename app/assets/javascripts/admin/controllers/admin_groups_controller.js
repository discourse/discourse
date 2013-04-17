Discourse.AdminGroupsController = Ember.ArrayController.extend({
  itemController: 'adminGroup',
  edit: function(action){
    this.get('content').select(action);
  }
});

Discourse.AdminGroupController = Ember.ObjectController.extend({

});
