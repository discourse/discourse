Discourse.AdminGroupsController = Ember.Controller.extend({
  itemController: 'adminGroup',

  edit: function(group){
    this.get('model').select(group);
    group.load();
  },

  refreshAutoGroups: function(){
    var controller = this;

    this.set('refreshingAutoGroups', true);
    Discourse.ajax('/admin/groups/refresh_automatic_groups', {type: 'POST'})
    .then(function() {
      controller.set('model', Discourse.Group.findAll());
      controller.set('refreshingAutoGroups', false);
    });
  },

  newGroup: function(){
    var group = Discourse.Group.create();
    group.set("loaded", true);
    var model = this.get("model");
    model.addObject(group);
    model.select(group);
  },

  save: function(group){
    if(!group.get("id")){
      group.create();
    } else {
      group.save();
    }
  },

  destroy: function(group){
    var _this = this;
    return bootbox.confirm(I18n.t("admin.groups.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
      if (result) {
        group.destroy().then(function(deleted) {
          if (deleted) {
            _this.get("model").removeObject(group);
          }
        });
      }
    });
  }
});

