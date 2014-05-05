Discourse.AdminGroupController = Em.ObjectController.extend({
  needs: ['adminGroups'],
  members: null,
  disableSave: false,

  aliasLevelOptions: function() {
    return [
      { name: I18n.t("groups.alias_levels.nobody"), value: 0},
      { name: I18n.t("groups.alias_levels.mods_and_admins"), value: 2},
      { name: I18n.t("groups.alias_levels.members_mods_and_admins"), value: 3},
      { name: I18n.t("groups.alias_levels.everyone"), value: 99}
    ];
  }.property(),

  usernames: function(key, value) {
    var members = this.get('members');
    if (arguments.length > 1) {
      this.set('_usernames', value);
    } else {
      var usernames;
      if(members) {
        usernames = members.map(function(user) {
          return user.get('username');
        }).join(',');
      }
      this.set('_usernames', usernames);
    }
    return this.get('_usernames');
  }.property('members.@each.username'),

  actions: {
    save: function() {
      var self = this,
          group = this.get('model');

      self.set('disableSave', true);

      var promise;
      if (group.get('id')) {
        promise = group.saveWithUsernames(this.get('usernames'));
      } else {
        promise = group.createWithUsernames(this.get('usernames')).then(function() {
          var groupsController = self.get('controllers.adminGroups');
          groupsController.addObject(group);
        });
      }
      promise.then(function() {
        self.send('showGroup', group);
      }, function(e) {
        var message = $.parseJSON(e.responseText).errors;
        bootbox.alert(message);
      }).finally(function() {
        self.set('disableSave', false);
      });
    },

    destroy: function() {
      var group = this.get('model'),
          groupsController = this.get('controllers.adminGroups'),
          self = this;

      bootbox.confirm(I18n.t("admin.groups.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          self.set('disableSave', true);
          group.destroy().then(function() {
            groupsController.get('model').removeObject(group);
            self.transitionToRoute('adminGroups.index');
          }, function() {
            bootbox.alert(I18n.t("admin.groups.delete_failed"));
          }).finally(function() {
            self.set('disableSave', false);
          });
        }
      });
    }
  }
});
