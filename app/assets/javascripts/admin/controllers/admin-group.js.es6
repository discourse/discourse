import { popupAjaxError } from 'discourse/lib/ajax-error';
import { propertyEqual } from 'discourse/lib/computed';

export default Ember.Controller.extend({
  needs: ['adminGroupsType'],
  disableSave: false,

  currentPage: function() {
    if (this.get("model.user_count") === 0) { return 0; }
    return Math.floor(this.get("model.offset") / this.get("model.limit")) + 1;
  }.property("model.limit", "model.offset", "model.user_count"),

  totalPages: function() {
    if (this.get("model.user_count") === 0) { return 0; }
    return Math.floor(this.get("model.user_count") / this.get("model.limit")) + 1;
  }.property("model.limit", "model.user_count"),

  showingFirst: Em.computed.lte("currentPage", 1),
  showingLast: propertyEqual("currentPage", "totalPages"),

  aliasLevelOptions: function() {
    return [
      { name: I18n.t("groups.alias_levels.nobody"), value: 0 },
      { name: I18n.t("groups.alias_levels.mods_and_admins"), value: 2 },
      { name: I18n.t("groups.alias_levels.members_mods_and_admins"), value: 3 },
      { name: I18n.t("groups.alias_levels.everyone"), value: 99 }
    ];
  }.property(),

  trustLevelOptions: function() {
    return [
      { name: I18n.t("groups.trust_levels.none"), value: 0 },
      { name: 1, value: 1 }, { name: 2, value: 2 }, { name: 3, value: 3 }, { name: 4, value: 4 }
    ];
  }.property(),

  actions: {
    next() {
      if (this.get("showingLast")) { return; }

      const group = this.get("model"),
            offset = Math.min(group.get("offset") + group.get("limit"), group.get("user_count"));

      group.set("offset", offset);

      return group.findMembers();
    },

    previous() {
      if (this.get("showingFirst")) { return; }

      const group = this.get("model"),
            offset = Math.max(group.get("offset") - group.get("limit"), 0);

      group.set("offset", offset);

      return group.findMembers();
    },

    removeMember(member) {
      const self = this,
            message = I18n.t("admin.groups.delete_member_confirm", { username: member.get("username"), group: this.get("model.name") });
      return bootbox.confirm(message, I18n.t("no_value"), I18n.t("yes_value"), function(confirm) {
        if (confirm) {
          self.get("model").removeMember(member);
        }
      });
    },

    addMembers() {
      if (Em.isEmpty(this.get("model.usernames"))) { return; }
      this.get("model").addMembers(this.get("model.usernames")).catch(popupAjaxError);
      this.set("model.usernames", null);
    },

    save() {
      const group = this.get('model'),
            groupsController = this.get("controllers.adminGroupsType"),
            groupType = groupsController.get("type");

      this.set('disableSave', true);

      let promise = group.get("id") ? group.save() : group.create().then(() => groupsController.addObject(group));

      promise.then(() => this.transitionToRoute("adminGroup", groupType, group.get('name')))
             .catch(popupAjaxError)
             .finally(() => this.set('disableSave', false));
    },

    destroy() {
      const group = this.get('model'),
            groupsController = this.get('controllers.adminGroupsType'),
            self = this;

      if (!group.get('id')) {
        self.transitionToRoute('adminGroupsType.index', 'custom');
        return;
      }

      this.set('disableSave', true);

      bootbox.confirm(
        I18n.t("admin.groups.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(confirmed) {
          if (confirmed) {
            group.destroy().then(() => {
              groupsController.get('model').removeObject(group);
              self.transitionToRoute('adminGroups.index');
            }).catch(() => bootbox.alert(I18n.t("admin.groups.delete_failed")))
              .finally(() => self.set('disableSave', false));
          } else {
            self.set('disableSave', false);
          }
        }
      );
    }
  }
});
