import CanCheckEmails from 'discourse/mixins/can-check-emails';
import { propertyNotEqual, setting } from 'discourse/lib/computed';

export default Ember.Controller.extend(CanCheckEmails, {
  editingTitle: false,
  originalPrimaryGroupId: null,
  availableGroups: null,

  showApproval: setting('must_approve_users'),
  showBadges: setting('enable_badges'),

  primaryGroupDirty: propertyNotEqual('originalPrimaryGroupId', 'model.primary_group_id'),

  automaticGroups: function() {
    return this.get("model.automaticGroups").map((g) => g.name).join(", ");
  }.property("model.automaticGroups"),

  userFields: function() {
    const siteUserFields = this.site.get('user_fields'),
          userFields = this.get('model.user_fields');

    if (!Ember.isEmpty(siteUserFields)) {
      return siteUserFields.map(function(uf) {
        let value = userFields ? userFields[uf.get('id').toString()] : null;
        return { name: uf.get('name'), value: value };
      });
    }
    return [];
  }.property('model.user_fields.@each'),

  actions: {
    toggleTitleEdit() {
      this.toggleProperty('editingTitle');
    },

    saveTitle() {
      const self = this;

      return Discourse.ajax("/users/" + this.get('model.username').toLowerCase(), {
        data: {title: this.get('model.title')},
        type: 'PUT'
      }).catch(function(e) {
        bootbox.alert(I18n.t("generic_error_with_reason", {error: "http: " + e.status + " - " + e.body}));
      }).finally(function() {
        self.send('toggleTitleEdit');
      });
    },

    generateApiKey() {
      this.get('model').generateApiKey();
    },

    groupAdded(added) {
      this.get('model').groupAdded(added).catch(function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    },

    groupRemoved(groupId) {
      this.get('model').groupRemoved(groupId).catch(function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    },

    savePrimaryGroup() {
      const self = this;

      return Discourse.ajax("/admin/users/" + this.get('model.id') + "/primary_group", {
        type: 'PUT',
        data: {primary_group_id: this.get('model.primary_group_id')}
      }).then(function () {
        self.set('originalPrimaryGroupId', self.get('model.primary_group_id'));
      }).catch(function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    },

    resetPrimaryGroup() {
      this.set('model.primary_group_id', this.get('originalPrimaryGroupId'));
    },

    regenerateApiKey() {
      const self = this;

      bootbox.confirm(
        I18n.t("admin.api.confirm_regen"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(result) {
          if (result) { self.get('model').generateApiKey(); }
        }
      );
    },

    revokeApiKey() {
      const self = this;

      bootbox.confirm(
        I18n.t("admin.api.confirm_revoke"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(result) {
          if (result) { self.get('model').revokeApiKey(); }
        }
      );
    },

    anonymize() {
      this.get('model').anonymize();
    },

    destroy() {
      this.get('model').destroy();
    }
  }

});
