export default Em.ObjectController.extend({
  needs: ['adminGroups'],
  disableSave: false,
  usernames: null,

  currentPage: function() {
    if (this.get("user_count") == 0) { return 0; }
    return Math.floor(this.get("offset") / this.get("limit")) + 1;
  }.property("limit", "offset", "user_count"),

  totalPages: function() {
    if (this.get("user_count") == 0) { return 0; }
    return Math.floor(this.get("user_count") / this.get("limit")) + 1;
  }.property("limit", "user_count"),

  showingFirst: Em.computed.lte("currentPage", 1),
  showingLast: Discourse.computed.propertyEqual("currentPage", "totalPages"),

  aliasLevelOptions: function() {
    return [
      { name: I18n.t("groups.alias_levels.nobody"), value: 0 },
      { name: I18n.t("groups.alias_levels.mods_and_admins"), value: 2 },
      { name: I18n.t("groups.alias_levels.members_mods_and_admins"), value: 3 },
      { name: I18n.t("groups.alias_levels.everyone"), value: 99 }
    ];
  }.property(),

  actions: {
    next: function() {
      if (this.get("showingLast")) { return; }

      var group = this.get("model"),
          offset = Math.min(group.get("offset") + group.get("limit"), group.get("user_count"));

      group.set("offset", offset);

      return group.findMembers();
    },

    previous: function() {
      if (this.get("showingFirst")) { return; }

      var group = this.get("model"),
          offset = Math.max(group.get("offset") - group.get("limit"), 0);

      group.set("offset", offset);

      return group.findMembers();
    },

    removeMember: function(member) {
      var self = this,
          message = I18n.t("admin.groups.delete_member_confirm", { username: member.get("username"), group: this.get("name") });
      return bootbox.confirm(message, I18n.t("no_value"), I18n.t("yes_value"), function(confirm) {
        if (confirm) {
          self.get("model").removeMember(member);
        }
      });
    },

    addMembers: function() {
      // TODO: should clear the input
      if (Em.isEmpty(this.get("usernames"))) { return; }
      this.get("model").addMembers(this.get("usernames"));
    },

    save: function() {
      var self = this,
          group = this.get('model');

      self.set('disableSave', true);

      var promise;
      if (group.get('id')) {
        promise = group.save();
      } else {
        promise = group.create().then(function() {
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
