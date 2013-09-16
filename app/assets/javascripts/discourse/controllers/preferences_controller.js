/**
  This controller supports actions related to updating one's preferences

  @class PreferencesController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesController = Discourse.ObjectController.extend({
  // By default we haven't saved anything
  saved: false,

  saveDisabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('name')) return true;
    if (this.blank('email')) return true;
    return false;
  }.property('saving', 'name', 'email'),

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
                            { name: I18n.t('user.new_topic_duration.last_here'), value: -2 }],

  saveButtonText: function() {
    return this.get('saving') ? I18n.t('saving') : I18n.t('save');
  }.property('saving'),

  actions: {
    save: function() {
      var self = this;
      this.set('saving', true);
      this.set('saved', false);

      // Cook the bio for preview
      var model = this.get('model');
      return model.save().then(function() {
        // model was saved
        self.set('saving', false);
        if (Discourse.User.currentProp('id') === model.get('id')) {
          Discourse.User.currentProp('name', model.get('name'));
        }
        self.set('bio_cooked', Discourse.Markdown.cook(self.get('bio_raw')));
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
    }
  }

});


