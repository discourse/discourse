Discourse.AdminGroupsController = Ember.Controller.extend({
  itemController: 'adminGroup',

  actions: {
    edit: function(group){
      this.get('model').select(group);
      group.load();
    },

    refreshAutoGroups: function(){
      var self = this;

      self.set('refreshingAutoGroups', true);
      Discourse.ajax('/admin/groups/refresh_automatic_groups', {type: 'POST'}).then(function() {
        self.set('model', Discourse.Group.findAll());
        self.set('refreshingAutoGroups', false);
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
      var self = this;
      return bootbox.confirm(I18n.t("admin.groups.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          group.destroy().then(function(deleted) {
            if (deleted) {
              self.get("model").removeObject(group);
            }
          });
        }
      });
    }
  }

});

