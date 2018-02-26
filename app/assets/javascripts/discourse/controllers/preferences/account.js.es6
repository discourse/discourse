import { iconHTML } from 'discourse-common/lib/icon-library';
import CanCheckEmails from 'discourse/mixins/can-check-emails';
import { default as computed } from "ember-addons/ember-computed-decorators";
import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { setting } from 'discourse/lib/computed';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(CanCheckEmails, PreferencesTabController, {

  saveAttrNames: ['name'],

  canEditName: setting('enable_names'),
  canSaveUser: true,

  newNameInput: null,

  passwordProgress: null,

  cannotDeleteAccount: Em.computed.not('currentUser.can_delete_account'),
  deleteDisabled: Em.computed.or('model.isSaving', 'deleting', 'cannotDeleteAccount'),

  reset() {
    this.setProperties({
      passwordProgress: null
    });
  },

  @computed()
  nameInstructions() {
    return I18n.t(this.siteSettings.full_name_required ? 'user.name.instructions_required' : 'user.name.instructions');
  },

  @computed("model.has_title_badges")
  canSelectTitle(hasTitleBadges) {
    return this.siteSettings.enable_badges && hasTitleBadges;
  },

  @computed()
  canChangePassword() {
    return !this.siteSettings.enable_sso && this.siteSettings.enable_local_logins;
  },

  @computed("model.second_factor_enabled")
  secondFactorStatusClass(secondFactorEnabled) {
    return secondFactorEnabled ? 'tip good' : 'tip bad';
  },

  actions: {
    save() {
      this.set('saved', false);

      const model = this.get('model');

      model.set('name', this.get('newNameInput'));

      return model.save(this.get('saveAttrNames')).then(() => {
        this.set('saved', true);
      }).catch(popupAjaxError);
    },

    changePassword() {
      if (!this.get('passwordProgress')) {
        this.set('passwordProgress', I18n.t("user.change_password.in_progress"));
        return this.get('model').changePassword().then(() => {
          // password changed
          this.setProperties({
            changePasswordProgress: false,
            passwordProgress: I18n.t("user.change_password.success")
          });
        }).catch(() => {
          // password failed to change
          this.setProperties({
            changePasswordProgress: false,
            passwordProgress: I18n.t("user.change_password.error")
          });
        });
      }
    },

    delete() {
      this.set('deleting', true);
      const self = this,
        message = I18n.t('user.delete_account_confirm'),
        model = this.get('model'),
        buttons = [
          { label: I18n.t("cancel"),
            class: "d-modal-cancel",
            link:  true,
            callback: () => { this.set('deleting', false); }
          },
          { label: iconHTML('exclamation-triangle') + I18n.t("user.delete_account"),
            class: "btn btn-danger",
            callback() {
              model.delete().then(function() {
                bootbox.alert(I18n.t('user.deleted_yourself'), function() {
                  window.location.pathname = Discourse.getURL('/');
                });
              }, function() {
                bootbox.alert(I18n.t('user.delete_yourself_not_allowed'));
                self.set('deleting', false);
              });
            }
          }
        ];
      bootbox.dialog(message, buttons, {"classes": "delete-account"});
    }
  }
});
