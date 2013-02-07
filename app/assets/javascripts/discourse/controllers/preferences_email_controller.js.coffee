Discourse.PreferencesEmailController = Ember.ObjectController.extend Discourse.Presence,

  taken: false
  saving: false
  error: false
  success: false

  saveDisabled: (->
    return true if @get('saving')
    return true if @blank('newEmail')
    return true if @get('taken')
    return true if @get('unchanged')
  ).property('newEmail', 'taken', 'unchanged', 'saving')

  unchanged: (->
    @get('newEmail') == @get('content.email')
  ).property('newEmail', 'content.email')

  initializeEmail: (->
    @set('newEmail', @get('content.email'))
  ).observes('content.email')

  saveButtonText: (->
    return Em.String.i18n("saving") if @get('saving')
    Em.String.i18n("user.change_email.action")
  ).property('saving')

  changeEmail: ->
    @set('saving', true)
    @get('content').changeEmail(@get('newEmail')).then =>
      @set('success', true)
    , =>
      # Error
      @set('error', true)
      @set('saving', false)
