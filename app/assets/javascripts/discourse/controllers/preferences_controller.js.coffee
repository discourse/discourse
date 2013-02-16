Discourse.PreferencesController = Ember.ObjectController.extend Discourse.Presence,

  # By default we haven't saved anything
  saved: false

  saveDisabled: (->
    return true if @get('saving')
    return true if @blank('content.name')
    return true if @blank('content.email')
    false
  ).property('saving', 'content.name', 'content.email')

  digestFrequencies: (->
    freqs = Em.A()
    freqs.addObject(name: Em.String.i18n('user.email_digests.daily'), value: 1)
    freqs.addObject(name: Em.String.i18n('user.email_digests.weekly'), value: 7)
    freqs.addObject(name: Em.String.i18n('user.email_digests.bi_weekly'), value: 14)
    freqs
  ).property()

  autoTrackDurations: (->
    freqs = Em.A()
    freqs.addObject(name: Em.String.i18n('user.auto_track_options.never'), value: -1)
    freqs.addObject(name: Em.String.i18n('user.auto_track_options.always'), value: 0)
    freqs.addObject(name: Em.String.i18n('user.auto_track_options.after_n_seconds', count: 30), value: 30000)
    freqs.addObject(name: Em.String.i18n('user.auto_track_options.after_n_minutes', count: 1), value: 60000)
    freqs.addObject(name: Em.String.i18n('user.auto_track_options.after_n_minutes', count: 2), value: 120000)
    freqs.addObject(name: Em.String.i18n('user.auto_track_options.after_n_minutes', count: 5), value: 300000)
    freqs.addObject(name: Em.String.i18n('user.auto_track_options.after_n_minutes', count: 10), value: 600000)
    freqs
  ).property()

  considerNewTopicOptions: (->
    opts = Em.A()
    opts.addObject(name: Em.String.i18n('user.new_topic_duration.not_viewed'), value: -1) # always
    opts.addObject(name: Em.String.i18n('user.new_topic_duration.after_n_days', count: 1), value: 60 * 24)
    opts.addObject(name: Em.String.i18n('user.new_topic_duration.after_n_days', count: 2), value: 60 * 48)
    opts.addObject(name: Em.String.i18n('user.new_topic_duration.after_n_weeks', count: 1), value: 7 * 60 * 24)
    opts.addObject(name: Em.String.i18n('user.new_topic_duration.last_here'), value: -2) # last visit
    opts
  ).property()

  save: ->
    @set('saving', true)
    @set('saved', false)

    # Cook the bio for preview
    @get('content').save (result) =>
      @set('saving', false)
      if result
        @set('content.bio_cooked', Discourse.Utilities.cook(@get('content.bio_raw')))
        @set('saved', true)
      else
        alert 'failed'

  saveButtonText: (->
    return Em.String.i18n('saving') if @get('saving')
    return Em.String.i18n('save')
  ).property('saving')

  changePassword: ->
    unless @get('passwordProgress')
      @set('passwordProgress','(generating email)')
      @get('content').changePassword (message)=>
        @set('changePasswordProgress', false)
        @set('passwordProgress', "(#{message})")
