Discourse.PreferencesUsernameController = Ember.ObjectController.extend Discourse.Presence,

  taken: false
  saving: false
  error: false
  errorMessage: null

  saveDisabled: (->
    return true if @get('saving')
    return true if @blank('newUsername')
    return true if @get('taken')
    return true if @get('unchanged')
    return true if @get('errorMessage')
    false
  ).property('newUsername', 'taken', 'errorMessage', 'unchanged', 'saving')

  unchanged: (->
    @get('newUsername') == @get('content.username')
  ).property('newUsername', 'content.username')

  checkTaken: (->
    @set('taken', false)
    @set('errorMessage', null)
    return if @blank('newUsername')
    return if @get('unchanged')
    Discourse.User.checkUsername(@get('newUsername')).then (result) =>
      if result.errors
        @set('errorMessage', result.errors.join(' '))
      else if result.available == false
        @set('taken', true)
  ).observes('newUsername')

  saveButtonText: (->
    return Em.String.i18n("saving") if @get('saving')
    Em.String.i18n("user.change_username.action")
  ).property('saving')

  changeUsername: ->
    bootbox.confirm Em.String.i18n("user.change_username.confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), (result) =>
      if result
        @set('saving', true)
        @get('content').changeUsername(@get('newUsername')).then =>
          window.location = "/users/#{@get('newUsername').toLowerCase()}/preferences"
        , =>
          # Error
          @set('error', true)
          @set('saving', false)
