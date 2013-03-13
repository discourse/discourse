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
    var _this = this, model = this.get('content');
    this.set('saving', true);
    this.set('saved', false);

    // Cook the bio for preview
    return model.save(function(result) {
      _this.set('saving', false);
      if (result) {
        if (Discourse.currentUser.id === model.get('id')) {
          Discourse.currentUser.set('name', model.get('name'));
        }
      
        _this.set('content.bio_cooked', Discourse.Markdown.cook(_this.get('content.bio_raw')));
        return _this.set('saved', true);
      } else {
        return alert('failed');
      }
    });
  },

  saveButtonText: (function() {
    if (this.get('saving')) return Em.String.i18n('saving');
    return Em.String.i18n('save');
  }).property('saving'),

  changePassword: function() {
    var _this = this;
    if (!this.get('passwordProgress')) {
      this.set('passwordProgress', '(generating email)');
      return this.get('content').changePassword(function(message) {
        _this.set('changePasswordProgress', false);
        return _this.set('passwordProgress', "(" + message + ")");
      });
    }
  }
});


