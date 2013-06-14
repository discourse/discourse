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

  saveDisabled: (function() {
    if (this.get('saving')) return true;
    if (this.blank('content.name')) return true;
    if (this.blank('content.email')) return true;
    return false;
  }).property('saving', 'content.name', 'content.email'),

  digestFrequencies: (function() {
    var freqs;
    freqs = Em.A();
    freqs.addObject({ name: Em.String.i18n('user.email_digests.daily'), value: 1 });
    freqs.addObject({ name: Em.String.i18n('user.email_digests.weekly'), value: 7 });
    freqs.addObject({ name: Em.String.i18n('user.email_digests.bi_weekly'), value: 14 });
    return freqs;
  }).property(),

  autoTrackDurations: (function() {
    var freqs;
    freqs = Em.A();
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.never'), value: -1 });
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.always'), value: 0 });
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.after_n_seconds', { count: 30 }), value: 30000 });
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.after_n_minutes', { count: 1 }), value: 60000 });
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.after_n_minutes', { count: 2 }), value: 120000 });
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.after_n_minutes', { count: 3 }), value: 180000 });
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.after_n_minutes', { count: 4 }), value: 240000 });
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.after_n_minutes', { count: 5 }), value: 300000 });
    freqs.addObject({ name: Em.String.i18n('user.auto_track_options.after_n_minutes', { count: 10 }), value: 600000 });
    return freqs;
  }).property(),

  considerNewTopicOptions: (function() {
    var opts;
    opts = Em.A();
    opts.addObject({ name: Em.String.i18n('user.new_topic_duration.not_viewed'), value: -1 });
    opts.addObject({ name: Em.String.i18n('user.new_topic_duration.after_n_days', { count: 1 }), value: 60 * 24 });
    opts.addObject({ name: Em.String.i18n('user.new_topic_duration.after_n_days', { count: 2 }), value: 60 * 48 });
    opts.addObject({ name: Em.String.i18n('user.new_topic_duration.after_n_weeks', { count: 1 }), value: 7 * 60 * 24 });
    opts.addObject({ name: Em.String.i18n('user.new_topic_duration.last_here'), value: -2 });
    return opts;
  }).property(),

  save: function() {
    var preferencesController = this;
    this.set('saving', true);
    this.set('saved', false);

    // Cook the bio for preview
    var model = this.get('content');
    return model.save().then(function() {
      // model was saved
      preferencesController.set('saving', false);
      if (Discourse.User.current('id') === model.get('id')) {
        Discourse.User.current().set('name', model.get('name'));
      }

      preferencesController.set('content.bio_cooked',
                                Discourse.Markdown.cook(preferencesController.get('content.bio_raw')));
      preferencesController.set('saved', true);
    }, function() {
      // model failed to save
      preferencesController.set('saving', false);
      alert(Em.String.i18n('generic_error'));
    });
  },

  saveButtonText: (function() {
    if (this.get('saving')) return Em.String.i18n('saving');
    return Em.String.i18n('save');
  }).property('saving'),

  changePassword: function() {
    var preferencesController = this;
    if (!this.get('passwordProgress')) {
      this.set('passwordProgress', Em.String.i18n("user.change_password.in_progress"));
      return this.get('content').changePassword().then(function() {
        // password changed
        preferencesController.setProperties({
          changePasswordProgress: false,
          passwordProgress: Em.String.i18n("user.change_password.success")
        });
      }, function() {
        // password failed to change
        preferencesController.setProperties({
          changePasswordProgress: false,
          passwordProgress: Em.String.i18n("user.change_password.error")
        });
      });
    }
  }
});


