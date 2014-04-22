Discourse.AdminGroupsController = Ember.Controller.extend({
  itemController: 'adminGroup',

  actions: {
    edit: function(group){
      this.get('model').select(group);
      group.loadUsers();
    },

    refreshAutoGroups: function(){
      var self = this;

      self.set('refreshingAutoGroups', true);
      Discourse.ajax('/admin/groups/refresh_automatic_groups', {type: 'POST'}).then(function() {
        return Discourse.Group.findAll().then(function(groups) {
          self.set('model', groups);
          self.set('refreshingAutoGroups', false);
        });
      });
    },

    newGroup: function(){
      var group = Discourse.Group.create({ loadedUsers: true, visible: true }),
          model = this.get("model");
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

