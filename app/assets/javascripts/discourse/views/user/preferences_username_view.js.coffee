window.Discourse.PreferencesUsernameView = Ember.View.extend
  templateName: 'user/username'
  classNames: ['user-preferences']

  didInsertElement: ->
    $('#change_username').focus()

  keyDown: (e) ->
    if e.keyCode is 13
      unless @get('controller').get('saveDisabled')
        @get('controller').changeUsername()
      else
        e.preventDefault()
        return false
