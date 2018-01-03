import { ajax } from 'discourse/lib/ajax';
import CanCheckEmails from 'discourse/mixins/can-check-emails';
import { propertyNotEqual, setting } from 'discourse/lib/computed';
import { userPath } from 'discourse/lib/url';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend(CanCheckEmails, {
  adminTools: Ember.inject.service(),
  editingUsername: false,
  editingName: false,
  editingTitle: false,
  originalPrimaryGroupId: null,
  availableGroups: null,
  userTitleValue: null,

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
  }.property('model.user_fields.[]'),

  @computed('model.username_lower')
  preferencesPath(username) {
    return userPath(`${username}/preferences`);
  },

  actions: {

    impersonate() { return this.get("model").impersonate(); },
    logOut() { return this.get("model").logOut(); },
    resetBounceScore() { return this.get("model").resetBounceScore(); },
    refreshBrowsers() { return this.get("model").refreshBrowsers(); },
    approve() { return this.get("model").approve(); },
    deactivate() { return this.get("model").deactivate(); },
    sendActivationEmail() { return this.get("model").sendActivationEmail(); },
    activate() { return this.get("model").activate(); },
    revokeAdmin() { return this.get("model").revokeAdmin(); },
    grantAdmin() { return this.get("model").grantAdmin(); },
    revokeModeration() { return this.get("model").revokeModeration(); },
    grantModeration() { return this.get("model").grantModeration(); },
    saveTrustLevel() { return this.get("model").saveTrustLevel(); },
    restoreTrustLevel() { return this.get("model").restoreTrustLevel(); },
    lockTrustLevel(locked) { return this.get("model").lockTrustLevel(locked); },
    unsilence() { return this.get("model").unsilence(); },
    silence() { return this.get("model").silence(); },
    deleteAllPosts() { return this.get("model").deleteAllPosts(); },
    anonymize() { return this.get('model').anonymize(); },
    destroy() { return this.get('model').destroy(); },

    showSuspendModal() {
      this.get('adminTools').showSuspendModal(this.get('model'));
    },
    unsuspend() {
      this.get("model").unsuspend().catch(popupAjaxError);
    },
    showSilenceModal() {
      this.get('adminTools').showSilenceModal(this.get('model'));
    },

    toggleUsernameEdit() {
      this.set('userUsernameValue', this.get('model.username'));
      this.toggleProperty('editingUsername');
    },

    saveUsername() {
      const oldUsername = this.get('model.username');
      this.set('model.username', this.get('userUsernameValue'));

      return ajax(`/users/${oldUsername.toLowerCase()}/preferences/username`, {
        data: { new_username: this.get('userUsernameValue') },
        type: 'PUT'
      }).catch(e => {
        this.set('model.username', oldUsername);
        popupAjaxError(e);
      }).finally(() => this.toggleProperty('editingUsername'));
    },

    toggleNameEdit() {
      this.set('userNameValue', this.get('model.name'));
      this.toggleProperty('editingName');
    },

    saveName() {
      const oldName = this.get('model.name');
      this.set('model.name', this.get('userNameValue'));

      return ajax(userPath(`${this.get('model.username').toLowerCase()}.json`), {
        data: { name: this.get('userNameValue') },
        type: 'PUT'
      }).catch(e => {
        this.set('model.name', oldName);
        popupAjaxError(e);
      }).finally(() => this.toggleProperty('editingName'));
    },

    toggleTitleEdit() {
      this.set('userTitleValue', this.get('model.title'));
      this.toggleProperty('editingTitle');
    },

    saveTitle() {
      const prevTitle = this.get('userTitleValue');

      this.set('model.title', this.get('userTitleValue'));
      return ajax(userPath(`${this.get('model.username').toLowerCase()}.json`), {
        data: {title: this.get('userTitleValue')},
        type: 'PUT'
      }).catch(e => {
        this.set('model.title', prevTitle);
        popupAjaxError(e);
      }).finally(() => this.toggleProperty('editingTitle'));
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

      return ajax("/admin/users/" + this.get('model.id') + "/primary_group", {
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
    }
  }

});
