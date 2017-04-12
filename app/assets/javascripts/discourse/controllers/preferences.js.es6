import { setting } from 'discourse/lib/computed';
import CanCheckEmails from 'discourse/mixins/can-check-emails';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import { cook } from 'discourse/lib/text';
import { NotificationLevels } from 'discourse/lib/notification-levels';
import { listThemes, selectDefaultTheme, previewTheme } from 'discourse/lib/theme-selector';

export default Ember.Controller.extend(CanCheckEmails, {

  userSelectableThemes: function(){
    return listThemes(this.site);
  }.property(),

  @observes("selectedTheme")
  themeKeyChanged() {
    let key = this.get("selectedTheme");
    previewTheme(key);
  },

  @computed("model.watchedCategories", "model.trackedCategories", "model.mutedCategories")
  selectedCategories(watched, tracked, muted) {
    return [].concat(watched, tracked, muted);
  },

  // By default we haven't saved anything
  saved: false,

  newNameInput: null,

  @computed("model.user_fields.@each.value")
  userFields() {
    let siteUserFields = this.site.get('user_fields');
    if (!Ember.isEmpty(siteUserFields)) {
      const userFields = this.get('model.user_fields');

      // Staff can edit fields that are not `editable`
      if (!this.get('currentUser.staff')) {
        siteUserFields = siteUserFields.filterBy('editable', true);
      }
      return siteUserFields.sortBy('position').map(function(field) {
        const value = userFields ? userFields[field.get('id').toString()] : null;
        return Ember.Object.create({ value, field });
      });
    }
  },

  cannotDeleteAccount: Em.computed.not('currentUser.can_delete_account'),
  deleteDisabled: Em.computed.or('model.isSaving', 'deleting', 'cannotDeleteAccount'),

  canEditName: setting('enable_names'),

  @computed()
  nameInstructions() {
    return I18n.t(this.siteSettings.full_name_required ? 'user.name.instructions_required' : 'user.name.instructions');
  },

  @computed("model.has_title_badges")
  canSelectTitle(hasTitleBadges) {
    return this.siteSettings.enable_badges && hasTitleBadges;
  },

  @computed("model.can_change_bio")
  canChangeBio(canChangeBio)
  {
    return canChangeBio;
  },

  @computed()
  canChangePassword() {
    return !this.siteSettings.enable_sso && this.siteSettings.enable_local_logins;
  },

  @computed()
  availableLocales() {
    return this.siteSettings.available_locales.split('|').map(s => ({ name: s, value: s }));
  },

  @computed()
  frequencyEstimate() {
    var estimate = this.get('model.mailing_list_posts_per_day');
    if (!estimate || estimate < 2) {
      return I18n.t('user.mailing_list_mode.few_per_day');
    } else {
      return I18n.t('user.mailing_list_mode.many_per_day', { dailyEmailEstimate: estimate });
    }
  },

  @computed()
  mailingListModeOptions() {
    return [
      {name: I18n.t('user.mailing_list_mode.daily'), value: 0},
      {name: this.get('frequencyEstimate'), value: 1},
      {name: I18n.t('user.mailing_list_mode.individual_no_echo'), value: 2}
    ];
  },

  previousRepliesOptions: [
    {name: I18n.t('user.email_previous_replies.always'), value: 0},
    {name: I18n.t('user.email_previous_replies.unless_emailed'), value: 1},
    {name: I18n.t('user.email_previous_replies.never'), value: 2}
  ],

  digestFrequencies: [{ name: I18n.t('user.email_digests.every_30_minutes'), value: 30 },
                      { name: I18n.t('user.email_digests.every_hour'), value: 60 },
                      { name: I18n.t('user.email_digests.daily'), value: 1440 },
                      { name: I18n.t('user.email_digests.every_three_days'), value: 4320 },
                      { name: I18n.t('user.email_digests.weekly'), value: 10080 },
                      { name: I18n.t('user.email_digests.every_two_weeks'), value: 20160 }],

  likeNotificationFrequencies: [{ name: I18n.t('user.like_notification_frequency.always'), value: 0 },
                      { name: I18n.t('user.like_notification_frequency.first_time_and_daily'), value: 1 },
                      { name: I18n.t('user.like_notification_frequency.first_time'), value: 2 },
                      { name: I18n.t('user.like_notification_frequency.never'), value: 3 }],

  autoTrackDurations: [{ name: I18n.t('user.auto_track_options.never'), value: -1 },
                       { name: I18n.t('user.auto_track_options.immediately'), value: 0 },
                       { name: I18n.t('user.auto_track_options.after_30_seconds'), value: 30000 },
                       { name: I18n.t('user.auto_track_options.after_1_minute'), value: 60000 },
                       { name: I18n.t('user.auto_track_options.after_2_minutes'), value: 120000 },
                       { name: I18n.t('user.auto_track_options.after_3_minutes'), value: 180000 },
                       { name: I18n.t('user.auto_track_options.after_4_minutes'), value: 240000 },
                       { name: I18n.t('user.auto_track_options.after_5_minutes'), value: 300000 },
                       { name: I18n.t('user.auto_track_options.after_10_minutes'), value: 600000 }],

  notificationLevelsForReplying: [{ name: I18n.t('topic.notifications.watching.title'), value: NotificationLevels.WATCHING },
                                  { name: I18n.t('topic.notifications.tracking.title'), value: NotificationLevels.TRACKING }],


  considerNewTopicOptions: [{ name: I18n.t('user.new_topic_duration.not_viewed'), value: -1 },
                            { name: I18n.t('user.new_topic_duration.after_1_day'), value: 60 * 24 },
                            { name: I18n.t('user.new_topic_duration.after_2_days'), value: 60 * 48 },
                            { name: I18n.t('user.new_topic_duration.after_1_week'), value: 7 * 60 * 24 },
                            { name: I18n.t('user.new_topic_duration.after_2_weeks'), value: 2 * 7 * 60 * 24 },
                            { name: I18n.t('user.new_topic_duration.last_here'), value: -2 }],

  @computed("model.isSaving")
  saveButtonText(isSaving) {
    return isSaving ? I18n.t('saving') : I18n.t('save');
  },

  reset() {
    this.setProperties({
      passwordProgress: null
    });
  },

  passwordProgress: null,

  actions: {

    save() {
      this.set('saved', false);

      const model = this.get('model');

      const userFields = this.get('userFields');

      // Update the user fields
      if (!Ember.isEmpty(userFields)) {
        const modelFields = model.get('user_fields');
        if (!Ember.isEmpty(modelFields)) {
          userFields.forEach(function(uf) {
            modelFields[uf.get('field.id').toString()] = uf.get('value');
          });
        }
      }

      // Cook the bio for preview
      model.set('name', this.get('newNameInput'));
      return model.save().then(() => {
        if (Discourse.User.currentProp('id') === model.get('id')) {
          Discourse.User.currentProp('name', model.get('name'));
        }
        model.set('bio_cooked', cook(model.get('bio_raw')));
        selectDefaultTheme(this.get('selectedTheme'));
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
              class: "cancel-inline",
              link:  true,
              callback: () => { this.set('deleting', false); }
            },
            { label: '<i class="fa fa-exclamation-triangle"></i> ' + I18n.t("user.delete_account"),
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
