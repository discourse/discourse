import { popupAjaxError } from 'discourse/lib/ajax-error';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  adminGroupsType: Ember.inject.controller(),
  disableSave: false,
  savingStatus: '',

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

  @computed('model.visible', 'model.public', 'model.alias_level')
  disableMembershipRequestSetting(visible, publicGroup) {
    return !visible || publicGroup || !this.get('model.canEveryoneMention');
  },

  @computed('model.visible', 'model.allow_membership_requests')
  disablePublicSetting(visible, allowMembershipRequests) {
    return !visible || allowMembershipRequests;
  },

  actions: {
    removeOwner(member) {
      const self = this,
            message = I18n.t("admin.groups.delete_owner_confirm", { username: member.get("username"), group: this.get("model.name") });
      return bootbox.confirm(message, I18n.t("no_value"), I18n.t("yes_value"), function(confirm) {
        if (confirm) {
          self.get("model").removeOwner(member);
        }
      });
    },

    addOwners() {
      if (Em.isEmpty(this.get("model.ownerUsernames"))) { return; }
      this.get("model").addOwners(this.get("model.ownerUsernames")).catch(popupAjaxError);
      this.set("model.ownerUsernames", null);
    },

    save() {
      const group = this.get('model'),
            groupsController = this.get("adminGroupsType"),
            groupType = groupsController.get("type");

      this.set('disableSave', true);
      this.set('savingStatus', I18n.t('saving'));

      let promise = group.get("id") ? group.save() : group.create().then(() => groupsController.get('model').addObject(group));

      promise.then(() => {
        this.transitionToRoute("adminGroup", groupType, group.get('name'));
        this.set('savingStatus', I18n.t('saved'));
      }).catch(popupAjaxError)
        .finally(() => this.set('disableSave', false));
    },

    destroy() {
      const group = this.get('model'),
            groupsController = this.get('adminGroupsType'),
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
