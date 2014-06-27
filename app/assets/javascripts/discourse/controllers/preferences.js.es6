/**
  This controller supports actions related to updating one's preferences

  @class PreferencesController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
export default Discourse.ObjectController.extend({

  allowAvatarUpload: Discourse.computed.setting('allow_uploaded_avatars'),
  allowUserLocale: Discourse.computed.setting('allow_user_locale'),

  selectedCategories: function(){
    return [].concat(this.get("watchedCategories"), this.get("trackedCategories"), this.get("mutedCategories"));
  }.property("watchedCategories", "trackedCategories", "mutedCategories"),

  // By default we haven't saved anything
  saved: false,

  newNameInput: null,

  saveDisabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('email')) return true;
    return false;
  }.property('saving', 'email'),

  cannotDeleteAccount: Em.computed.not('can_delete_account'),
  deleteDisabled: Em.computed.or('saving', 'deleting', 'cannotDeleteAccount'),

  canEditName: Discourse.computed.setting('enable_names'),

  canSelectTitle: function() {
    return Discourse.SiteSettings.enable_badges && this.get('model.badge_count') > 0;
  }.property('model.badge_count'),

  availableLocales: function() {
    return Discourse.SiteSettings.available_locales.split('|').map( function(s) {
      return {name: s, value: s};
    });
  }.property(),

  digestFrequencies: [{ name: I18n.t('user.email_digests.daily'), value: 1 },
                      { name: I18n.t('user.email_digests.weekly'), value: 7 },
                      { name: I18n.t('user.email_digests.bi_weekly'), value: 14 }],

  autoTrackDurations: [{ name: I18n.t('user.auto_track_options.never'), value: -1 },
                       { name: I18n.t('user.auto_track_options.always'), value: 0 },
                       { name: I18n.t('user.auto_track_options.after_n_seconds', { count: 30 }), value: 30000 },
                       { name: I18n.t('user.auto_track_options.after_n_minutes', { count: 1 }), value: 60000 },
                       { name: I18n.t('user.auto_track_options.after_n_minutes', { count: 2 }), value: 120000 },
                       { name: I18n.t('user.auto_track_options.after_n_minutes', { count: 3 }), value: 180000 },
                       { name: I18n.t('user.auto_track_options.after_n_minutes', { count: 4 }), value: 240000 },
                       { name: I18n.t('user.auto_track_options.after_n_minutes', { count: 5 }), value: 300000 },
                       { name: I18n.t('user.auto_track_options.after_n_minutes', { count: 10 }), value: 600000 }],

  considerNewTopicOptions: [{ name: I18n.t('user.new_topic_duration.not_viewed'), value: -1 },
                            { name: I18n.t('user.new_topic_duration.after_n_days', { count: 1 }), value: 60 * 24 },
                            { name: I18n.t('user.new_topic_duration.after_n_days', { count: 2 }), value: 60 * 48 },
                            { name: I18n.t('user.new_topic_duration.after_n_weeks', { count: 1 }), value: 7 * 60 * 24 },
                            { name: I18n.t('user.new_topic_duration.after_n_weeks', { count: 2 }), value: 2 * 7 * 60 * 24 },
                            { name: I18n.t('user.new_topic_duration.last_here'), value: -2 }],

  saveButtonText: function() {
    return this.get('saving') ? I18n.t('saving') : I18n.t('save');
  }.property('saving'),

  imageUploadUrl: Discourse.computed.url('username', '/users/%@/preferences/user_image'),

  actions: {

    save: function() {
      var self = this;
      this.setProperties({ saving: true, saved: false });

      // Cook the bio for preview
      var model = this.get('model');
      model.set('name', this.get('newNameInput'));
      return model.save().then(function() {
        // model was saved
        self.set('saving', false);
        if (Discourse.User.currentProp('id') === model.get('id')) {
          Discourse.User.currentProp('name', model.get('name'));
        }
        self.set('bio_cooked', Discourse.Markdown.cook(Discourse.Markdown.sanitize(self.get('bio_raw'))));
        self.set('saved', true);
      }, function() {
        // model failed to save
        self.set('saving', false);
        alert(I18n.t('generic_error'));
      });
    },

    changePassword: function() {
      var self = this;
      if (!this.get('passwordProgress')) {
        this.set('passwordProgress', I18n.t("user.change_password.in_progress"));
        return this.get('model').changePassword().then(function() {
          // password changed
          self.setProperties({
            changePasswordProgress: false,
            passwordProgress: I18n.t("user.change_password.success")
          });
        }, function() {
          // password failed to change
          self.setProperties({
            changePasswordProgress: false,
            passwordProgress: I18n.t("user.change_password.error")
          });
        });
      }
    },

    delete: function() {
      this.set('deleting', true);
      var self = this,
          message = I18n.t('user.delete_account_confirm'),
          model = this.get('model'),
          buttons = [{
        "label": I18n.t("cancel"),
        "class": "cancel-inline",
        "link":  true,
        "callback": function() {
          self.set('deleting', false);
        }
      }, {
        "label": '<i class="fa fa-exclamation-triangle"></i> ' + I18n.t("user.delete_account"),
        "class": "btn btn-danger",
        "callback": function() {
          model.delete().then(function() {
            bootbox.alert(I18n.t('user.deleted_yourself'), function() {
              window.location.pathname = Discourse.getURL('/');
            });
          }, function() {
            bootbox.alert(I18n.t('user.delete_yourself_not_allowed'));
            self.set('deleting', false);
          });
        }
      }];
      bootbox.dialog(message, buttons, {"classes": "delete-account"});
    }
  }

});


